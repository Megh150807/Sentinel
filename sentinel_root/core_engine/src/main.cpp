// ═══════════════════════════════════════════════════════════════════════════════
//  main.cpp — Sentinel Core Engine Entry Point
//
//  HTTP server receiving Pub/Sub push webhooks from the GCP pipeline.
//  Orchestrates: Sieve inference → Graph threat analysis → Firestore alert.
// ═══════════════════════════════════════════════════════════════════════════════

#include <httplib.h>
#include "nlohmann/json.hpp"
#include "sieve_xgboost.hpp"
#include "graph_sniper.hpp"
#include "firestore_client.hpp"
#include <curl/curl.h>   // curl_global_init / curl_global_cleanup
#include <iostream>
#include <string>
#include <cstdlib>   // std::getenv
#include <chrono>

using json = nlohmann::json;

// ─────────────────────────────────────────────────
//  Configuration helpers
// ─────────────────────────────────────────────────

/// Returns SENTINEL_MODEL_PATH env var, falling back to "xgboost.json".
static std::string resolve_model_path() {
    const char* env = std::getenv("SENTINEL_MODEL_PATH");
    if (env && env[0] != '\0') {
        std::cout << "[Config] Model path from env: " << env << "\n";
        return std::string(env);
    }
    std::cout << "[Config] SENTINEL_MODEL_PATH not set — using default: xgboost.json\n";
    return "xgboost.json";
}

/// Returns SENTINEL_GCP_PROJECT env var, falling back to placeholder.
static std::string resolve_project_id() {
    const char* env = std::getenv("SENTINEL_GCP_PROJECT");
    return (env && env[0] != '\0') ? std::string(env) : "sentinel-project";
}

// ─────────────────────────────────────────────────
//  Mock history builder (replace with real ledger lookup)
// ─────────────────────────────────────────────────
static std::vector<AccountEvent> build_mock_history(float amount, int event_count) {
    std::vector<AccountEvent> history;
    history.reserve(event_count);
    const double now = std::chrono::duration_cast<std::chrono::duration<double>>(
        std::chrono::system_clock::now().time_since_epoch()
    ).count();

    // Simulate a rapid fan-out: alternating credit → debit pairs
    for (int i = 0; i < event_count; ++i) {
        AccountEvent ev;
        ev.timestamp_epoch_s = now - (event_count - i) * 8.0; // ~8s apart
        ev.amount_inr        = amount * 0.9f;  // slight amount drift
        ev.is_outgoing       = (i % 2 != 0);   // alternating
        history.push_back(ev);
    }
    return history;
}

// ─────────────────────────────────────────────────
//  main()
// ─────────────────────────────────────────────────

int main() {
    // ── Fix Issue #3: curl_global_init must be called ONCE at process start,
    //    not inside the FirestoreClient constructor (not thread-safe there).
    curl_global_init(CURL_GLOBAL_ALL);

    // ── Sub-system init ──────────────────────────────────────────────────────
    const std::string model_path  = resolve_model_path();
    const std::string project_id  = resolve_project_id();

    SieveXGBoost* sieve = nullptr;
    try {
        sieve = new SieveXGBoost(model_path);
    } catch (const std::exception& e) {
        std::cerr << "[WARN] Sieve ML module unavailable: " << e.what()
                  << "\n       Running in heuristic-only mode.\n";
    }

    GraphSniper    sniper;
    FirestoreClient firestore(project_id);

    // Mock graph state — replace with live ledger feeds
    std::vector<Transaction> mock_txs = {
        {"A", "B", 50000.0f},
        {"A", "C", 30000.0f},
        {"B", "D", 48000.0f},
        {"C", "E", 29500.0f}
    };
    sniper.load_graph(mock_txs);
    std::cout << "[Engine] Graph loaded: " << mock_txs.size() << " edges\n";

    // ── HTTP Server ──────────────────────────────────────────────────────────
    httplib::Server svr;

    svr.Post("/pubsub", [&](const httplib::Request& req, httplib::Response& res) {
        try {
            auto payload = json::parse(req.body);

            if (!payload.contains("message") ||
                !payload["message"].contains("data")) {
                res.status = 400;
                return;
            }

            // ── In production: decode base64 Pub/Sub data & extract fields ──
            // For now, use representative simulation values:
            const float  trigger_amount = 50000.0f;     // INR
            const int    event_count    = 8;             // events in last 120s
            const auto   history        = build_mock_history(trigger_amount, event_count);
            const std::string node_id   = "A";

            // ── Stage 1+2+3: Sieve Classification ───────────────────────────
            MuleClassification verdict = MuleClassification::BENIGN;
            float ml_fallback_score    = 0.5f;

            if (sieve) {
                verdict = sieve->classify(trigger_amount, history, 120.0);
            } else {
                // Heuristic-only fallback when model is unavailable
                ml_fallback_score = 0.8f;
                verdict = MuleClassification::HUMAN_MULE;
            }

            // ── Graph Threat Score ───────────────────────────────────────────
            const float graph_risk     = sniper.analyze_syndicate_centrality(node_id);
            const float ml_risk        = sieve
                ? sieve->evaluate(trigger_amount, event_count, 8000.0f)
                : ml_fallback_score;

            // Combined scoring: 60% ML / 40% graph topology
            const float combined_score = ml_risk * 0.6f + graph_risk * 0.4f;

            std::cout << "[Engine] Node=" << node_id
                      << " | Verdict=" << classification_label(verdict)
                      << " | ML=" << ml_risk
                      << " | Graph=" << graph_risk
                      << " | Combined=" << combined_score << "\n";

            // ── Interdiction Threshold ───────────────────────────────────────
            const bool is_critical = (verdict == MuleClassification::CRITICAL_MULE)
                                  || (verdict != MuleClassification::BENIGN && combined_score >= 0.90f);

            if (is_critical) {
                json alert;
                alert["fields"]["score"]["doubleValue"]      = combined_score;
                alert["fields"]["verdict"]["stringValue"]    = classification_label(verdict);
                alert["fields"]["node_id"]["stringValue"]    = node_id;
                alert["fields"]["trigger_amount"]["doubleValue"] = trigger_amount;
                alert["fields"]["timestamp"]["stringValue"]  = std::to_string(
                    std::chrono::system_clock::now().time_since_epoch().count()
                );

                firestore.push_alert(alert.dump());
                std::cout << "[!] INTERDICTION FIRED → Firestore alert written.\n";
            }

            res.status = 200;

        } catch (const json::exception& e) {
            std::cerr << "[Engine] JSON parse error: " << e.what() << "\n";
            res.status = 400;
        } catch (const std::exception& e) {
            std::cerr << "[Engine] Internal error: " << e.what() << "\n";
            res.status = 500;
        }
    });

    // Health-check for Cloud Run / load balancer
    svr.Get("/health", [](const httplib::Request&, httplib::Response& res) {
        res.set_content("{\"status\":\"operational\"}", "application/json");
        res.status = 200;
    });

    std::cout << "╔══════════════════════════════════════════╗\n";
    std::cout << "║   SENTINEL ENGINE — LOCKED & LOADED      ║\n";
    std::cout << "║   Listening on 0.0.0.0:8080              ║\n";
    std::cout << "╚══════════════════════════════════════════╝\n";

    svr.listen("0.0.0.0", 8080);

    delete sieve;
    curl_global_cleanup();
    return 0;
}

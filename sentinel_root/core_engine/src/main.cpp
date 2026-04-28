// ═══════════════════════════════════════════════════════════════════════════════
//  main.cpp — Sentinel Core Engine Entry Point
//
//  Synchronous Cloud Run REST Microservice.
//  Orchestrates: XGBoost Sieve inference + GraphSniper centrality analysis.
// ═══════════════════════════════════════════════════════════════════════════════

#include <iostream>
#include <string>
#include <cstdlib>
#include <chrono>
#include "httplib.h"
#include "nlohmann/json.hpp"
#include "sieve_xgboost.hpp"
#include "graph_sniper.hpp"

using json = nlohmann::json;

// ─────────────────────────────────────────────────
//  Configuration helpers
// ─────────────────────────────────────────────────
static std::string resolve_model_path() {
    const char* env = std::getenv("SENTINEL_MODEL_PATH");
    if (env && env[0] != '\0') {
        return std::string(env);
    }
    return "xgboost_model.json";
}

// ─────────────────────────────────────────────────
//  main()
// ─────────────────────────────────────────────────

int main() {
    const std::string model_path = resolve_model_path();

    SieveXGBoost* sieve = nullptr;
    try {
        sieve = new SieveXGBoost(model_path);
        std::cout << "[Engine] XGBoost Sieve initialized.\n";
    } catch (const std::exception& e) {
        std::cerr << "[WARN] Sieve ML module unavailable: " << e.what()
                  << "\n       Running in fallback mode.\n";
    }

    // GraphSniper for syndicate centrality analysis
    GraphSniper graph;

    httplib::Server svr;

    svr.Options("/intercept", [](const httplib::Request&, httplib::Response& res) {
        res.set_header("Access-Control-Allow-Origin", "*");
        res.set_header("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
        res.set_header("Access-Control-Allow-Headers", "Content-Type");
        res.status = 200;
    });

    svr.Post("/intercept", [&](const httplib::Request& req, httplib::Response& res) {
        res.set_header("Access-Control-Allow-Origin", "*");
        auto start = std::chrono::high_resolution_clock::now();

        try {
            auto payload = json::parse(req.body);

            const std::string txn_id = payload.value("transaction_id", "UNKNOWN");
            const float jitter_ms    = payload.value("jitter_ms", 0.0f);
            const float ptr          = payload.value("ptr", 0.0f);

            // ── Synthesize features matching the trained model ──────────────
            // The real model was trained on: [amount, txn_count_120s, ptr_ratio, jitter_sigma]
            float synth_amount = ptr > 0.85f ? 10000.0f : 100.0f;
            float txn_count_120s = jitter_ms < 500.0f ? 10.0f : 2.0f;
            float ptr_ratio = ptr;
            float jitter_sigma = jitter_ms / 1000.0f; // Convert ms to seconds

            bool is_blocked = false;
            float ml_risk = 0.0f;

            if (sieve) {
                ml_risk = sieve->evaluate(synth_amount, txn_count_120s, ptr_ratio, jitter_sigma);
                
                // Block if ML risk is high, OR heuristic thresholds are crossed
                if (ml_risk > 0.70f || ptr > 0.85f || jitter_ms < 100.0f) {
                    is_blocked = true;
                }
            } else {
                // Fallback heuristic if XGBoost fails to load
                if (ptr > 0.85f || jitter_ms < 100.0f) {
                    is_blocked = true;
                }
            }

            // ── GraphSniper: Build live transaction graph ────────────────────
            // Edges are sender_upi → receiver_upi (real account identifiers)
            // Mule accounts accumulate edges (high centrality), legit accounts stay isolated
            const std::string sender = payload.value("sender_upi", "");
            const std::string receiver = payload.value("receiver_upi", "");

            float centrality = 0.0f;
            if (!sender.empty() && !receiver.empty()) {
                graph.add_transaction({sender, receiver, synth_amount});
                float sender_centrality = graph.analyze_syndicate_centrality(sender);
                float receiver_centrality = graph.analyze_syndicate_centrality(receiver);
                centrality = std::max(sender_centrality, receiver_centrality);
            }

            // ── Flag blocked UPI IDs and detect mule rings ──────────────────
            // Only flag the RECEIVER — they're the account collecting money (the mule).
            // The sender may be an innocent victim who got scammed.
            json rings_json = json::array();
            if (is_blocked && !sender.empty() && !receiver.empty()) {
                graph.flag_node(receiver, txn_id);

                auto rings = graph.detect_rings();
                for (const auto& ring : rings) {
                    json rj;
                    rj["chain"] = ring.chain;
                    rj["evidence_txn_ids"] = ring.transaction_ids;
                    rings_json.push_back(rj);

                    std::cout << "[GraphSniper] RING: ";
                    for (const auto& node : ring.chain) std::cout << node << " -> ";
                    std::cout << "END (" << ring.transaction_ids.size() << " evidence txns)\n";
                }
            }

            auto end = std::chrono::high_resolution_clock::now();
            auto duration_us = std::chrono::duration_cast<std::chrono::microseconds>(end - start).count();

            json response;
            response["status"] = is_blocked ? "blocked" : "allowed";
            response["latency_us"] = duration_us;
            response["transaction_id"] = txn_id;
            response["sender_upi"] = sender;
            response["receiver_upi"] = receiver;
            response["ml_risk_score"] = ml_risk;
            response["centrality_score"] = centrality;
            response["ptr"] = ptr;
            response["jitter_ms"] = jitter_ms;
            if (!rings_json.empty()) {
                response["rings"] = rings_json;
            }

            std::cout << "[Engine] Processed " << txn_id << " in " << duration_us << "us."
                      << " Status: " << response["status"]
                      << " | ML: " << ml_risk
                      << " | Centrality: " << centrality << "\n";

            res.set_content(response.dump(), "application/json");
            res.status = 200;

        } catch (const json::exception& e) {
            std::cerr << "[Engine] JSON parse error: " << e.what() << "\n";
            res.status = 400;
        } catch (const std::exception& e) {
            std::cerr << "[Engine] Internal error: " << e.what() << "\n";
            res.status = 500;
        }
    });

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
    return 0;
}

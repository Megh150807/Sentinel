// ═══════════════════════════════════════════════════════════════════════════════
//  sieve_xgboost.cpp — Sentinel Sieve Inference Engine
//
//  Implements the full three-stage classification pipeline per directive:
//    Stage 1 — Ignition Gate        (amount >= ₹7,500 INR)
//    Stage 2 — Time-Window Analysis (last 120 seconds of account history)
//      └─ PTR check    → CRITICAL_MULE if outgoing/incoming >= 0.95
//      └─ Jitter check → BOT (σ < 0.5s) or HUMAN_MULE (σ > 0.5s + velocity)
//    Stage 3 — XGBoost ML Fallback  (inconclusive heuristics path)
// ═══════════════════════════════════════════════════════════════════════════════

#include "sieve_xgboost.hpp"

#include <stdexcept>
#include <vector>
#include <numeric>
#include <cmath>
#include <algorithm>
#include <chrono>
#include <iostream>

// ─────────────────────────────────────────────────
//  Sieve Algorithmic Constants (per directive)
// ─────────────────────────────────────────────────

static constexpr float  IGNITION_THRESHOLD_INR  = 7500.0f;  ///< Minimum INR to trigger evaluation
static constexpr double TIME_WINDOW_SECONDS      = 120.0;    ///< Look-back window in seconds
static constexpr float  PTR_CRITICAL_THRESHOLD   = 0.95f;   ///< Pass-Through Rate → CRITICAL_MULE
static constexpr double JITTER_BOT_THRESHOLD_S   = 0.5;     ///< σ < 0.5s → BOT pattern
static constexpr int    HIGH_VELOCITY_MIN_EVENTS = 5;       ///< Minimum events/window = high velocity

// ─────────────────────────────────────────────────
//  Internal helpers
// ─────────────────────────────────────────────────

namespace {

/// Returns the current Unix epoch in seconds.
double now_epoch_s() {
    using namespace std::chrono;
    return duration_cast<duration<double>>(
        system_clock::now().time_since_epoch()
    ).count();
}

/// Filters history to events within [now - window_s, now].
std::vector<AccountEvent> filter_window(
    const std::vector<AccountEvent>& history,
    double time_window_s)
{
    const double cutoff = now_epoch_s() - time_window_s;
    std::vector<AccountEvent> windowed;
    windowed.reserve(history.size());
    for (const auto& ev : history) {
        if (ev.timestamp_epoch_s >= cutoff) {
            windowed.push_back(ev);
        }
    }
    return windowed;
}

/// Computes pass-through rate: sum(outgoing) / sum(incoming).
/// Returns -1.0f if there are no incoming transactions (division guard).
float compute_ptr(const std::vector<AccountEvent>& events) {
    float incoming_sum = 0.0f;
    float outgoing_sum = 0.0f;
    for (const auto& ev : events) {
        if (ev.is_outgoing) {
            outgoing_sum += ev.amount_inr;
        } else {
            incoming_sum += ev.amount_inr;
        }
    }
    if (incoming_sum <= 0.0f) return -1.0f; // No credits — cannot compute PTR
    return outgoing_sum / incoming_sum;
}

/// Computes the standard deviation of transaction timestamps in seconds.
/// Returns 0.0 when fewer than 2 events are present.
double compute_jitter_stddev(const std::vector<AccountEvent>& events) {
    if (events.size() < 2) return 0.0;

    const size_t n = events.size();
    double sum = 0.0;
    for (const auto& ev : events) sum += ev.timestamp_epoch_s;
    const double mean = sum / static_cast<double>(n);

    double sq_sum = 0.0;
    for (const auto& ev : events) {
        const double diff = ev.timestamp_epoch_s - mean;
        sq_sum += diff * diff;
    }
    return std::sqrt(sq_sum / static_cast<double>(n - 1)); // sample std-dev
}

} // anonymous namespace


// ─────────────────────────────────────────────────
//  SieveXGBoost — Constructor / Destructor
// ─────────────────────────────────────────────────

SieveXGBoost::SieveXGBoost(std::string_view model_path) {
    if (XGBoosterCreate(nullptr, 0, &booster_) != 0) {
        throw std::runtime_error("XGBoost: Failed to create booster handle");
    }
    if (XGBoosterLoadModel(booster_, model_path.data()) != 0) {
        XGBoosterFree(booster_);
        booster_ = nullptr;
        throw std::runtime_error(
            std::string("XGBoost: Failed to load model from: ") + std::string(model_path)
        );
    }
    std::cout << "[Sieve] XGBoost model loaded from: " << model_path << "\n";
}

SieveXGBoost::~SieveXGBoost() {
    if (booster_) {
        XGBoosterFree(booster_);
        booster_ = nullptr;
    }
}


// ─────────────────────────────────────────────────
//  STAGE 1 + 2 + 3 — Full Classify Pipeline
// ─────────────────────────────────────────────────

MuleClassification SieveXGBoost::classify(
    float trigger_amount_inr,
    const std::vector<AccountEvent>& history,
    double time_window_s) const
{
    // ── STAGE 1: Ignition Gate ──────────────────────────────────────────────
    // Directive: "Only evaluate transactions where amount >= ₹7,500 INR"
    if (trigger_amount_inr < IGNITION_THRESHOLD_INR) {
        std::cout << "[Sieve] Ignition gate: ₹" << trigger_amount_inr
                  << " < ₹" << IGNITION_THRESHOLD_INR << " → BENIGN (skip)\n";
        return MuleClassification::BENIGN;
    }
    std::cout << "[Sieve] Ignition gate PASSED: ₹" << trigger_amount_inr << "\n";

    // ── STAGE 2: Time-Window Analysis (last `time_window_s` seconds) ────────
    // Directive: "Look at the last 120 seconds of account history"
    const auto windowed = filter_window(history, time_window_s);
    std::cout << "[Sieve] Events in " << time_window_s
              << "s window: " << windowed.size() << "\n";

    if (!windowed.empty()) {

        // ── PTR CHECK ───────────────────────────────────────────────────────
        // Directive: "Flag as CRITICAL_MULE if (outgoing_sum / incoming_sum) >= 0.95"
        const float ptr = compute_ptr(windowed);
        if (ptr >= 0.0f) { // -1 means no incoming events (skip ratio check)
            std::cout << "[Sieve] PTR = " << ptr
                      << " (threshold " << PTR_CRITICAL_THRESHOLD << ")\n";
            if (ptr >= PTR_CRITICAL_THRESHOLD) {
                std::cout << "[Sieve] *** PTR BREACH → CRITICAL_MULE ***\n";
                return MuleClassification::CRITICAL_MULE;
            }
        } else {
            std::cout << "[Sieve] PTR skipped — no incoming transactions in window\n";
        }

        // ── JITTER VARIANCE CHECK ───────────────────────────────────────────
        // Directive:
        //   σ < 0.5s → BOT
        //   σ > 0.5s AND high velocity → HUMAN_MULE
        const double jitter_stddev = compute_jitter_stddev(windowed);
        std::cout << "[Sieve] Jitter σ = " << jitter_stddev << "s\n";

        if (jitter_stddev < JITTER_BOT_THRESHOLD_S && windowed.size() >= 2) {
            // Robotically uniform inter-transaction spacing
            std::cout << "[Sieve] *** Jitter < 0.5s → BOT ***\n";
            return MuleClassification::BOT;
        }

        const bool high_velocity = static_cast<int>(windowed.size()) >= HIGH_VELOCITY_MIN_EVENTS;
        if (jitter_stddev > JITTER_BOT_THRESHOLD_S && high_velocity) {
            // Human-like variance but abnormally high transaction frequency
            std::cout << "[Sieve] *** Jitter > 0.5s + high velocity → HUMAN_MULE ***\n";
            return MuleClassification::HUMAN_MULE;
        }
    }

    // ── STAGE 3: XGBoost ML Fallback ────────────────────────────────────────
    // Heuristics were inconclusive — delegate to the trained model.
    // We use event count and trigger amount as proxy features.
    const float event_count_f = static_cast<float>(windowed.size());
    // Estimate a synthetic inter-event interval in ms from the window
    const float synthetic_interval_ms = windowed.size() > 1
        ? static_cast<float>(time_window_s * 1000.0 / (windowed.size() - 1))
        : 0.0f;

    const float ml_score = evaluate(trigger_amount_inr, static_cast<int>(event_count_f), synthetic_interval_ms);
    std::cout << "[Sieve] ML fallback score = " << ml_score << "\n";

    // Thresholds for ML-path classification
    if (ml_score >= 0.80f) return MuleClassification::HUMAN_MULE;
    if (ml_score >= 0.50f) return MuleClassification::BOT;
    return MuleClassification::BENIGN;
}


// ─────────────────────────────────────────────────
//  Raw XGBoost C-API Evaluate (ML Fallback)
// ─────────────────────────────────────────────────

float SieveXGBoost::evaluate(
    float transaction_amount,
    int   passes_through_count,
    float time_interval_ms) const
{
    if (!booster_) return 0.0f; // Graceful degradation if model failed

    // Single-row feature matrix: [amount, hop_count, interval_ms]
    float data[3] = {
        transaction_amount,
        static_cast<float>(passes_through_count),
        time_interval_ms
    };

    DMatrixHandle dmatrix;
    if (XGDMatrixCreateFromMat(data, 1, 3, /*missing=*/-1.0f, &dmatrix) != 0) {
        return 0.0f;
    }

    bst_ulong out_len = 0;
    const float* out_result = nullptr;

    // Predict (option mask 0 = normal prediction, ntree_limit 0 = use all trees)
    if (XGBoosterPredict(booster_, dmatrix, /*option_mask=*/0,
                         /*ntree_limit=*/0, /*training=*/0,
                         &out_len, &out_result) != 0) {
        XGDMatrixFree(dmatrix);
        return 0.0f;
    }

    const float score = (out_len > 0 && out_result) ? out_result[0] : 0.0f;
    XGDMatrixFree(dmatrix);
    return score;
}

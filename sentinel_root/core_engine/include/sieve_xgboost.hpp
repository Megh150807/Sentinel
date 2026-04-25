#pragma once
#include <string_view>
#include <vector>
#include <cstdint>
#include <xgboost/c_api.h>

// ─────────────────────────────────────────────────
//  Sentinel Sieve — Public Classification API
//  Implements the Ignition / PTR / Jitter Variance
//  algorithmic directives for UPI mule detection.
// ─────────────────────────────────────────────────

/// Result classification returned by the Sieve.
enum class MuleClassification : uint8_t {
    BENIGN       = 0,  ///< Below ignition threshold or clean heuristics
    HUMAN_MULE   = 1,  ///< High velocity, human-pattern jitter (σ > 0.5s)
    BOT          = 2,  ///< Robotic pattern, jitter std-dev < 0.5s
    CRITICAL_MULE = 3  ///< Pass-Through Rate >= 0.95 — immediate interdiction
};

/// A single ledger event in an account's recent history.
struct AccountEvent {
    double  timestamp_epoch_s; ///< Unix epoch seconds (fractional)
    float   amount_inr;        ///< Transaction amount in INR
    bool    is_outgoing;       ///< true = debit, false = credit
};

/// Returns a human-readable label for logging / alerts.
constexpr const char* classification_label(MuleClassification c) noexcept {
    switch (c) {
        case MuleClassification::BENIGN:        return "BENIGN";
        case MuleClassification::HUMAN_MULE:    return "HUMAN_MULE";
        case MuleClassification::BOT:           return "BOT";
        case MuleClassification::CRITICAL_MULE: return "CRITICAL_MULE";
    }
    return "UNKNOWN";
}

class SieveXGBoost {
public:
    explicit SieveXGBoost(std::string_view model_path);
    ~SieveXGBoost();

    // Non-copyable — owns a native BoosterHandle
    SieveXGBoost(const SieveXGBoost&) = delete;
    SieveXGBoost& operator=(const SieveXGBoost&) = delete;

    /// Primary Sieve entry point.
    /// @param trigger_amount_inr   The amount that triggered this evaluation.
    /// @param history              Recent account events to analyse.
    /// @param time_window_s        Seconds to look back (default 120s).
    /// @returns MuleClassification verdict.
    MuleClassification classify(
        float trigger_amount_inr,
        const std::vector<AccountEvent>& history,
        double time_window_s = 120.0
    ) const;

    /// Raw ML score [0,1] — used as a fallback when heuristics are inconclusive.
    /// @param transaction_amount   INR amount
    /// @param passes_through_count Number of relay hops
    /// @param time_interval_ms     Time between hops in milliseconds
    float evaluate(float transaction_amount,
                   int   passes_through_count,
                   float time_interval_ms) const;

private:
    BoosterHandle booster_ = nullptr;
};

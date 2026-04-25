#include "../include/sieve_xgboost.hpp"
#include <iostream>
#include <vector>
#include <chrono>

AccountEvent make_tx(double offset_sec, float amt, bool out) {
    auto now = std::chrono::duration_cast<std::chrono::duration<double>>(
        std::chrono::system_clock::now().time_since_epoch()
    ).count();
    return {now + offset_sec, amt, out};
}

int main() {
    std::cout << "\n=== SENTINEL PROVING GROUND ===\n\n";
    
    // We instantiate with a non-existent path to force the ML fallback to test purely Heuristics.
    // The engine handles missing models gracefully.
    SieveXGBoost sieve("xgboost.json");
    
    // ----------------------------------------------------
    // TEST 1: Normal Transaction (Ignored)
    // Amount < 7500 INR
    // ----------------------------------------------------
    std::cout << "--- [TEST 1] Standard Low-Value Transaction ---\n";
    std::vector<AccountEvent> history_normal; 
    auto res1 = sieve.classify(5000.0f, history_normal);
    std::cout << ">> EXPECTED: BENIGN | RESULT: " << classification_label(res1) << "\n\n";

    // ----------------------------------------------------
    // TEST 2: Automated Bot Attack
    // Ignition passed (>= 7500), Low PTR (< 0.95), Jitter < 0.5s
    // NOTE: To reach jitter logic, PTR must be < 0.95, otherwise it instantly flags CRITICAL_MULE.
    // ----------------------------------------------------
    std::cout << "--- [TEST 2] Automated Bot Spacing Simulation (Low Jitter) ---\n";
    // 5 events, exactly 0.2s apart. StdDev = low variance
    std::vector<AccountEvent> history_bot = {
        make_tx(-1.0, 10000.0f, false),
        make_tx(-0.8,  2000.0f, true),
        make_tx(-0.6, 10000.0f, false),
        make_tx(-0.4,  2000.0f, true),
        make_tx(-0.2, 10000.0f, false)
    };
    auto res2 = sieve.classify(15000.0f, history_bot);
    std::cout << ">> EXPECTED: BOT | RESULT: " << classification_label(res2) << "\n\n";

    // ----------------------------------------------------
    // TEST 3: Human Mule Attack
    // Ignition passed, High PTR (>= 0.95), High Velocity
    // ----------------------------------------------------
    std::cout << "--- [TEST 3] Panic Human Mule Attack (High PTR) ---\n";
    // Rapid drain behavior. All incoming funds immediately outgoing.
    // PTR = 1.0 (100% drained)
    std::vector<AccountEvent> history_mule = {
        make_tx(-10.0, 50000.0f, false), // Deposit 50k
        make_tx(-2.0,  25000.0f, true),  // Draining 25k (irregular interval)
        make_tx(-0.5,  25000.0f, true)   // Draining 25k (irregular interval)
    };
    auto res3 = sieve.classify(55000.0f, history_mule);
    std::cout << ">> EXPECTED: CRITICAL_MULE | RESULT: " << classification_label(res3) << "\n\n";

    return 0;
}

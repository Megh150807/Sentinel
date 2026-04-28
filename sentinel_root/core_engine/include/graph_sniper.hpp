#pragma once
#include <string_view>
#include <vector>
#include <unordered_map>
#include <unordered_set>
#include <string>
#include <mutex>

struct Transaction {
    std::string source_id;
    std::string dest_id;
    float amount;
};

/// A detected mule chain: ordered path of flagged UPI IDs + evidence transaction IDs.
struct RingReport {
    std::vector<std::string> chain;           // Ordered UPI IDs forming the mule chain
    std::vector<std::string> transaction_ids; // TXN IDs that revealed the chain
    bool detected = false;
};

class GraphSniper {
public:
    // Injects a graph state
    void load_graph(const std::vector<Transaction>& transactions);
    
    // Traversing graph asynchronously using std::async
    // Returning centrality score for risk assessment (bidirectional degree)
    float analyze_syndicate_centrality(std::string_view target_node_id);

    // Dynamically inject a single edge (bidirectional tracking)
    void add_transaction(const Transaction& tx);

    // Mark a UPI ID as flagged (involved in a blocked transaction)
    // and record which transaction ID revealed it.
    void flag_node(const std::string& node_id, const std::string& txn_id);

    // Detect ALL mule chains: finds every connected component of flagged nodes.
    // Returns one RingReport per distinct ring.
    std::vector<RingReport> detect_rings();

    // Extract a local subgraph (edges) for visualization in frontend
    std::vector<Transaction> get_edges_for_alert(std::string_view target_node_id, int depth = 2);
    
private:
    // Bidirectional adjacency lists
    std::unordered_map<std::string, std::vector<std::string>> adj_out_;  // sender → [receivers]
    std::unordered_map<std::string, std::vector<std::string>> adj_in_;   // receiver → [senders]

    // Flagged (blocked) node tracking
    std::unordered_set<std::string> flagged_nodes_;
    std::unordered_map<std::string, std::vector<std::string>> node_txn_ids_; // UPI → [txn_ids]

    std::mutex mutex_;
};

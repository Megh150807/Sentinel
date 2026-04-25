#include "graph_sniper.hpp"
#include <queue>
#include <unordered_set>
#include <mutex>
#include <thread>
#include <future>
#include <algorithm>

void GraphSniper::load_graph(const std::vector<Transaction>& transactions) {
    adj_list_.clear();
    for(const auto& tx : transactions) {
        adj_list_[tx.source_id].push_back(tx.dest_id);
    }
}

float GraphSniper::analyze_syndicate_centrality(std::string_view target_node_id) {
    // Simplified degree-based and short-depth centrality analysis using std::async for parallel processing of branches.
    std::string start_node(target_node_id);
    if(adj_list_.find(start_node) == adj_list_.end()) return 0.0f;
    
    const auto& neighbors = adj_list_[start_node];
    if (neighbors.empty()) return 0.0f;

    std::vector<std::future<float>> futures;
    
    for (const auto& neighbor : neighbors) {
        futures.push_back(std::async(std::launch::async, [this, neighbor]() -> float {
            // Traverse 1 step deeper locally
            auto it = adj_list_.find(neighbor);
            if (it == adj_list_.end()) return 0.0f;
            return static_cast<float>(it->second.size());
        }));
    }
    
    float total_centrality = static_cast<float>(neighbors.size());
    for (auto& fut : futures) {
        total_centrality += fut.get() * 0.5f; // Weighted deeper impact
    }
    
    // Normalize logic (placeholder maximum cap of 100 connections)
    float risk = total_centrality / 100.0f;
    return std::min(risk, 1.0f);
}

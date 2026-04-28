#include "graph_sniper.hpp"
#include <queue>
#include <unordered_set>
#include <mutex>
#include <thread>
#include <future>
#include <algorithm>
#include <iostream>

// ─────────────────────────────────────────────────
//  Graph Construction (Bidirectional)
// ─────────────────────────────────────────────────

void GraphSniper::load_graph(const std::vector<Transaction>& transactions) {
    adj_out_.clear();
    adj_in_.clear();
    for(const auto& tx : transactions) {
        adj_out_[tx.source_id].push_back(tx.dest_id);
        adj_in_[tx.dest_id].push_back(tx.source_id);
    }
}

void GraphSniper::add_transaction(const Transaction& tx) {
    std::lock_guard<std::mutex> lock(mutex_);
    adj_out_[tx.source_id].push_back(tx.dest_id);
    adj_in_[tx.dest_id].push_back(tx.source_id);
}

// ─────────────────────────────────────────────────
//  Flagged Node Tracking
// ─────────────────────────────────────────────────

void GraphSniper::flag_node(const std::string& node_id, const std::string& txn_id) {
    std::lock_guard<std::mutex> lock(mutex_);
    flagged_nodes_.insert(node_id);
    node_txn_ids_[node_id].push_back(txn_id);
}

// ─────────────────────────────────────────────────
//  Subgraph Extraction (BFS)
// ─────────────────────────────────────────────────

std::vector<Transaction> GraphSniper::get_edges_for_alert(std::string_view target_node_id, int depth) {
    std::vector<Transaction> edges;
    std::string start_node(target_node_id);
    
    std::lock_guard<std::mutex> lock(mutex_);
    
    std::unordered_set<std::string> visited;
    std::queue<std::pair<std::string, int>> q;
    
    q.push({start_node, 0});
    visited.insert(start_node);

    // BFS to gather the local subgraph (outgoing edges)
    while (!q.empty()) {
        auto [current_node, current_depth] = q.front();
        q.pop();

        if (current_depth >= depth) continue;

        auto it = adj_out_.find(current_node);
        if (it != adj_out_.end()) {
            for (const auto& neighbor : it->second) {
                edges.push_back({current_node, neighbor, 10000.0f});
                
                if (visited.find(neighbor) == visited.end()) {
                    visited.insert(neighbor);
                    q.push({neighbor, current_depth + 1});
                }
            }
        }
    }
    
    return edges;
}

// ─────────────────────────────────────────────────
//  Centrality (Bidirectional Degree)
// ─────────────────────────────────────────────────

float GraphSniper::analyze_syndicate_centrality(std::string_view target_node_id) {
    std::string start_node(target_node_id);

    std::unique_lock<std::mutex> lock(mutex_);

    // Compute bidirectional degree: out-degree + in-degree
    float out_degree = 0.0f;
    float in_degree = 0.0f;

    auto out_it = adj_out_.find(start_node);
    if (out_it != adj_out_.end()) {
        out_degree = static_cast<float>(out_it->second.size());
    }

    auto in_it = adj_in_.find(start_node);
    if (in_it != adj_in_.end()) {
        in_degree = static_cast<float>(in_it->second.size());
    }

    if (out_degree == 0.0f && in_degree == 0.0f) return 0.0f;

    // Collect unique neighbors (both in and out) for deeper analysis
    std::unordered_set<std::string> all_neighbors;
    if (out_it != adj_out_.end()) {
        for (const auto& n : out_it->second) all_neighbors.insert(n);
    }
    if (in_it != adj_in_.end()) {
        for (const auto& n : in_it->second) all_neighbors.insert(n);
    }

    // Copy neighbor list so we can release lock during async
    std::vector<std::string> neighbors_vec(all_neighbors.begin(), all_neighbors.end());
    lock.unlock();

    // Async: compute each neighbor's total degree for weighted centrality
    std::vector<std::future<float>> futures;
    for (const auto& neighbor : neighbors_vec) {
        futures.push_back(std::async(std::launch::async, [this, neighbor]() -> float {
            std::lock_guard<std::mutex> inner_lock(mutex_);
            float n_degree = 0.0f;
            auto o = adj_out_.find(neighbor);
            if (o != adj_out_.end()) n_degree += static_cast<float>(o->second.size());
            auto i = adj_in_.find(neighbor);
            if (i != adj_in_.end()) n_degree += static_cast<float>(i->second.size());
            return n_degree;
        }));
    }

    float total_centrality = out_degree + in_degree;
    for (auto& fut : futures) {
        total_centrality += fut.get() * 0.5f; // Weighted deeper impact
    }

    // Dynamic normalization based on actual graph size
    float graph_size = static_cast<float>(std::max(adj_out_.size(), static_cast<size_t>(1)));
    float risk = total_centrality / graph_size;
    return std::min(risk, 1.0f);
}

// ─────────────────────────────────────────────────
//  Ring Detection — All connected components of flagged nodes
// ─────────────────────────────────────────────────
//
//  Strategy:
//    1. Iterate over all flagged nodes.
//    2. For each unvisited flagged node, do BFS following outgoing edges
//       but ONLY traverse to other flagged nodes.
//    3. Each BFS produces one connected component = one mule ring.
//    4. Only report components with 2+ nodes (a single node isn't a ring).
//

std::vector<RingReport> GraphSniper::detect_rings() {
    std::lock_guard<std::mutex> lock(mutex_);

    std::vector<RingReport> rings;

    if (flagged_nodes_.size() < 2) return rings;

    // Global visited set — ensures each flagged node belongs to at most one ring
    std::unordered_set<std::string> globally_visited;

    for (const auto& start : flagged_nodes_) {
        if (globally_visited.count(start)) continue;

        // BFS from this flagged node, following edges to other flagged nodes
        std::vector<std::string> component;
        std::queue<std::string> q;
        q.push(start);
        globally_visited.insert(start);

        while (!q.empty()) {
            std::string node = q.front();
            q.pop();
            component.push_back(node);

            // Follow outgoing edges
            auto out_it = adj_out_.find(node);
            if (out_it != adj_out_.end()) {
                std::unordered_set<std::string> unique_out(out_it->second.begin(), out_it->second.end());
                for (const auto& neighbor : unique_out) {
                    if (flagged_nodes_.count(neighbor) && !globally_visited.count(neighbor)) {
                        globally_visited.insert(neighbor);
                        q.push(neighbor);
                    }
                }
            }

            // Follow incoming edges (bidirectional connectivity)
            auto in_it = adj_in_.find(node);
            if (in_it != adj_in_.end()) {
                std::unordered_set<std::string> unique_in(in_it->second.begin(), in_it->second.end());
                for (const auto& neighbor : unique_in) {
                    if (flagged_nodes_.count(neighbor) && !globally_visited.count(neighbor)) {
                        globally_visited.insert(neighbor);
                        q.push(neighbor);
                    }
                }
            }
        }

        // Only report if the component has 2+ flagged nodes
        if (component.size() >= 2) {
            // Topological ordering: sort by dependency (sources first)
            // Find nodes with no flagged incoming edges → they're the chain start
            std::vector<std::string> ordered;
            std::unordered_set<std::string> comp_set(component.begin(), component.end());
            std::unordered_set<std::string> placed;

            // Simple topological sort via repeated source removal
            while (placed.size() < comp_set.size()) {
                bool progress = false;
                for (const auto& node : component) {
                    if (placed.count(node)) continue;

                    // Check if all flagged predecessors are already placed
                    bool ready = true;
                    auto in_it = adj_in_.find(node);
                    if (in_it != adj_in_.end()) {
                        for (const auto& pred : in_it->second) {
                            if (comp_set.count(pred) && !placed.count(pred)) {
                                ready = false;
                                break;
                            }
                        }
                    }

                    if (ready) {
                        ordered.push_back(node);
                        placed.insert(node);
                        progress = true;
                    }
                }
                if (!progress) {
                    // Cycle detected — just append remaining
                    for (const auto& node : component) {
                        if (!placed.count(node)) {
                            ordered.push_back(node);
                            placed.insert(node);
                        }
                    }
                    break;
                }
            }

            RingReport report;
            report.detected = true;
            report.chain = ordered;

            // Collect deduplicated evidence transaction IDs
            std::unordered_set<std::string> seen_txns;
            for (const auto& node : ordered) {
                auto txn_it = node_txn_ids_.find(node);
                if (txn_it != node_txn_ids_.end()) {
                    for (const auto& txn : txn_it->second) {
                        if (seen_txns.insert(txn).second) {
                            report.transaction_ids.push_back(txn);
                        }
                    }
                }
            }

            rings.push_back(std::move(report));
        }
    }

    return rings;
}

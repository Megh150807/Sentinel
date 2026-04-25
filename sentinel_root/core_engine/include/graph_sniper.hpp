#pragma once
#include <string_view>
#include <vector>
#include <unordered_map>
#include <string>

struct Transaction {
    std::string source_id;
    std::string dest_id;
    float amount;
};

class GraphSniper {
public:
    // Injects a graph state
    void load_graph(const std::vector<Transaction>& transactions);
    
    // Traversing graph asynchronously using OpenMP concepts / std::thread
    // Returning centrality score for risk assessment
    float analyze_syndicate_centrality(std::string_view target_node_id);
    
private:
    std::unordered_map<std::string, std::vector<std::string>> adj_list_;
};

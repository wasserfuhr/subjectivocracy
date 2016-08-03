contract RealityToken {

    struct Branch {
        bytes32 parent_hash; // Hash of the parent branch.
        bytes32 merkle_root; // Merkel root of the data we commit to
        uint256 timestamp; // Timestamp branch was mined
        uint256 window; // Day x of the system's operation, starting at UTC 00:00:00
        mapping(address => int256) balance_change;
    }

    mapping(bytes32 => Branch) public branches;
    mapping(address => uint256) public user_latest_windows;

    uint256 public window0timestamp; // 00:00:00 UTC on the day the contract was mined

    function RealityToken() {
        window0timestamp = now - (now % 86400);
        bytes32 null_hash;
        bytes32 genesis_merkel_root = sha3("I leave to several futures (not to all) my garden of forking paths");
        bytes32 genesis_branch_hash = sha3(null_hash, genesis_merkel_root);
        branches[genesis_branch_hash] = Branch(null_hash, genesis_merkel_root, now, 0);
        branches[genesis_branch_hash].balance_change[msg.sender] = 2100000000000000;
    }

    function sendCoin(address addr, uint256 amount, bytes32 to_branch) returns (bool) {
        if (amount > 2100000000000000) {
            throw;
        }
        // Spends, which may cause debits, can only go forwards. 
        // That way when we check if you have enough to spend we only have to go backwards.
        uint256 branch_window = branches[to_branch].window;
        if (branch_window < user_latest_windows[msg.sender]) {
            return false;
        }
        if (!isBalanceAtLeast(msg.sender, amount, to_branch)) {
            return false;
        }
        user_latest_windows[msg.sender] = branches[to_branch].window; 
        branches[to_branch].balance_change[msg.sender] -= int256(amount);
        branches[to_branch].balance_change[addr] += int256(amount);
        return true;
    }

    // Crawl up towards the root of the tree until we get enough, or return false if we never do.
    // You never have negative balance above you, so if you have enough credit at any point then return.
    // This uses less gas than getBalance, which always has to go all the way to the root.
    function isBalanceAtLeast(address addr, uint256 _min_balance, bytes32 branch_hash) constant returns (bool) {
        if (_min_balance > 2100000000000000) {
            throw;
        }
        int256 bal = 0;
        int256 min_balance = int256(_min_balance);
        bytes32 null_hash;
        while(branch_hash != null_hash) {
            bal += branches[branch_hash].balance_change[addr];
            if (bal >= min_balance) {
                return true;
            }
            branch_hash = branches[branch_hash].parent_hash;
        }
        return false;
    }

    function getBalance(address addr, bytes32 branch_hash) constant returns (uint256) {
        int256 bal = 0;
        bytes32 null_hash;
        while(branch_hash != null_hash) {
            bal += branches[branch_hash].balance_change[addr];
            branch_hash = branches[branch_hash].parent_hash;
        }
        return uint256(bal);
    }

    function createBranch(bytes32 parent_b_hash, bytes32 merkle_root) returns (bytes32) {
        bytes32 null_hash;
        bytes32 branch_hash = sha3(parent_b_hash, merkle_root);
        // Probably impossible to make sha3 come out all zeroes but check to be safe
        if (branch_hash == null_hash) {
            throw;
        }
        // You can only create a branch once. Check existence by timestamp, all branches have one.
        if (branches[branch_hash].timestamp > 0) {
            throw;
        }
        // Parent branch must exist, which we check by seeing if its timestamp is set
        if (branches[parent_b_hash].timestamp == 0) {
            throw;
        }
        uint256 window = (now - window0timestamp) / 86400;
        // We must now be a later 24-hour window than the parent
        if (branches[parent_b_hash].window >= window) {
            throw;
        }
        branches[branch_hash] = Branch(parent_b_hash, merkle_root, now, window);
        return branch_hash;
    }
}

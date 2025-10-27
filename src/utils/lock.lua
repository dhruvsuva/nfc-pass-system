-- Redis Lua script for atomic pass verification and marking as used
-- This script ensures that a pass can only be marked as used once atomically

-- KEYS[1]: active passes hash key (active:passes)
-- KEYS[2]: verify lock key prefix (lock:verify:)
-- KEYS[3]: uid of the pass
-- ARGV[1]: lock TTL in seconds
-- ARGV[2]: current timestamp

local active_passes_key = KEYS[1]
local lock_key_prefix = KEYS[2]
local uid = KEYS[3]
local lock_ttl = tonumber(ARGV[1]) or 10
local current_time = ARGV[2]

local lock_key = lock_key_prefix .. uid

-- Try to acquire lock
local lock_acquired = redis.call('SET', lock_key, '1', 'EX', lock_ttl, 'NX')
if not lock_acquired then
    return {"error", "lock_failed", "Another verification is in progress for this pass"}
end

-- Get pass data from active passes hash
local pass_data_json = redis.call('HGET', active_passes_key, uid)
if not pass_data_json then
    -- Release lock before returning
    redis.call('DEL', lock_key)
    return {"error", "not_found", "Pass not found in active cache"}
end

-- Parse pass data
local pass_data = cjson.decode(pass_data_json)

-- Check if pass is already used
if pass_data.status == 'used' then
    -- Release lock before returning
    redis.call('DEL', lock_key)
    return {"error", "already_used", "Pass has already been used"}
end

-- Check if pass is valid (not expired)
if pass_data.valid_to then
    local valid_to_timestamp = pass_data.valid_to
    local current_timestamp = current_time
    
    -- Simple date comparison (assuming ISO format)
    if valid_to_timestamp < current_timestamp then
        -- Release lock before returning
        redis.call('DEL', lock_key)
        return {"error", "expired", "Pass has expired"}
    end
end

-- Mark pass as used
pass_data.status = 'used'
pass_data.used_at = current_time

-- Update pass data in Redis
local updated_pass_data = cjson.encode(pass_data)
redis.call('HSET', active_passes_key, uid, updated_pass_data)

-- Release lock
redis.call('DEL', lock_key)

-- Return success with pass data
return {"success", pass_data.pass_id, pass_data.pass_db_id, pass_data.people_allowed, pass_data.category, pass_data.pass_type}
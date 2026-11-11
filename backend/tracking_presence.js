const TRACKING_LOCATION_TIMEOUT_MS = 2 * 60 * 1000;

function expireStaleAgentTracking(
    activeAgents,
    lastKnownAgents,
    now = Date.now(),
    timeoutMs = TRACKING_LOCATION_TIMEOUT_MS
) {
    const expiredAgents = [];

    for (const [agentId, agent] of activeAgents) {
        const lastActivity = Date.parse(agent.lastUpdated ?? agent.startedAt ?? '');
        if (Number.isFinite(lastActivity) && now - lastActivity < timeoutMs) {
            continue;
        }

        const offlineAgent = {
            ...agent,
            status: 'offline',
            isTracking: false,
            offlineReason: 'location_timeout',
            offlineAt: new Date(now).toISOString(),
        };
        activeAgents.delete(agentId);
        lastKnownAgents.set(agentId, offlineAgent);
        expiredAgents.push(offlineAgent);
    }

    return expiredAgents;
}

function restoreExpiredAgentForLocation(
    agentId,
    activeAgents,
    lastKnownAgents,
    trackingIntents,
    now = Date.now()
) {
    const activeAgent = activeAgents.get(agentId);
    if (activeAgent) return activeAgent;
    if (!trackingIntents.has(agentId)) return null;

    const previousAgent = lastKnownAgents.get(agentId);
    const agent = {
        ...previousAgent,
        stambuk: agentId,
        startedAt: previousAgent?.startedAt ?? new Date(now).toISOString(),
        locationSuspicious: previousAgent?.locationSuspicious ?? false,
        locationWarnings: previousAgent?.locationWarnings ?? [],
        status: 'active',
        isTracking: true,
    };
    delete agent.offlineAt;
    delete agent.offlineReason;
    delete agent.stoppedAt;
    activeAgents.set(agentId, agent);
    return agent;
}

module.exports = {
    TRACKING_LOCATION_TIMEOUT_MS,
    expireStaleAgentTracking,
    restoreExpiredAgentForLocation,
};

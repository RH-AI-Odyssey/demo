package org.acme.model;

import java.util.List;

//https://docs.gitlab.com/ee/user/project/integrations/webhook_events.html#push-events

public class GitlabEvent {

    public List<Commit> commits;

    public Repository repository;
}

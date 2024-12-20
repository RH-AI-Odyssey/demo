package org.acme;

import java.time.LocalDateTime;

import org.acme.model.GitlabEvent;

import io.quarkus.runtime.StartupEvent;
import jakarta.enterprise.event.Observes;
import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

@Path("/embedder")
public class EmbedderResource {

    @Inject
    Ingestion ingestion;

    void start(@Observes StartupEvent event) {
        ingestion.ingest("Today it's "+LocalDateTime.now());
    }
    
    @POST
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.TEXT_PLAIN)
    public String hello(GitlabEvent event) {
        return "Hello from Quarkus REST";
    }
}

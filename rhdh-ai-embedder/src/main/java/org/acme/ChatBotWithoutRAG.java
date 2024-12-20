package org.acme;

import io.quarkiverse.langchain4j.RegisterAiService;
import jakarta.enterprise.context.ApplicationScoped;

@RegisterAiService(
    chatMemoryProviderSupplier=RegisterAiService.NoChatMemoryProviderSupplier.class
)
//FIXME TODO I'm not worried about different users
@ApplicationScoped
public interface ChatBotWithoutRAG {

    String chat(String question);

}

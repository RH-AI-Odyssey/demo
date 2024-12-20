package org.acme;

import io.quarkiverse.langchain4j.RegisterAiService;
import jakarta.enterprise.context.ApplicationScoped;

@RegisterAiService(
    retrievalAugmentor = Retriever.class,
    chatMemoryProviderSupplier=RegisterAiService.NoChatMemoryProviderSupplier.class
    )
//FIXME TODO I'm not worried about different users
@ApplicationScoped
public interface ChatBot {

    String chat(String question);

}

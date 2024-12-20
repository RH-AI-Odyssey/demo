package org.acme;

import io.quarkus.logging.Log;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.inject.Named;

@ApplicationScoped
@Named("chatBot")
public class ChatBotBean {

    @Inject
    ChatBot chatBot;

    @Inject
    ChatBotWithoutRAG chatBotWithoutRAG;

    public String chat(String question) {
        Log.infof("chatWithRAG %s", question);
        return chatBot.chat(question);
    }

    public String chatWithoutRAG(String question) {
        Log.infof("chatWithoutRAG %s", question);
        return chatBotWithoutRAG.chat(question);
    }

}

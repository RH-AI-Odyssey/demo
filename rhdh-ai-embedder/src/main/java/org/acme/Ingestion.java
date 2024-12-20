package org.acme;

import static dev.langchain4j.data.document.splitter.DocumentSplitters.recursive;

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;

import dev.langchain4j.data.document.BlankDocumentException;
import dev.langchain4j.data.document.Document;
import dev.langchain4j.data.document.DocumentParser;
import dev.langchain4j.data.document.parser.TextDocumentParser;
import dev.langchain4j.data.segment.TextSegment;
import dev.langchain4j.model.embedding.EmbeddingModel;
import dev.langchain4j.store.embedding.EmbeddingStore;
import dev.langchain4j.store.embedding.EmbeddingStoreIngestor;
import io.quarkus.logging.Log;
import jakarta.inject.Named;
import jakarta.inject.Singleton;

@Singleton
// @Startup
@Named("ingestion")
public class Ingestion {

    private static final TextDocumentParser PARSER = new TextDocumentParser();
    EmbeddingStoreIngestor ingestor;

    public Ingestion(EmbeddingStore<TextSegment> store, EmbeddingModel embedding) { 
        Log.infof(("Ingestion store: %s"), store);
        Log.infof(("Ingestion embedding: %s"), embedding);
        ingestor = EmbeddingStoreIngestor.builder()
                .embeddingStore(store)
                .embeddingModel(embedding)
                .documentSplitter(recursive(1024, 0))  
                .build();

    }

    public void ingest(String input) {
        try {
            this.ingestor.ingest(load(input, PARSER));
        } catch(Exception e) {
            Log.errorf(e, "Erro");
        }
        
        Log.info("Ingestion.ingest(OK) ");
    }

    private static Document load(String source, DocumentParser parser) {
        try (InputStream inputStream = new ByteArrayInputStream(source.getBytes(StandardCharsets.UTF_8))) {
            Document document = parser.parse(inputStream);
            // source.metadata().asMap().forEach((key, value) -> document.metadata().put(key, value));
            return document;
        } catch (BlankDocumentException e) {
            throw e;
        } catch (Exception e) {
            throw new RuntimeException("Failed to load document", e);
        }
    }

}
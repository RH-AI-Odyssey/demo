package org.acme;

import java.net.Socket;
import java.security.cert.X509Certificate;

import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLEngine;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509ExtendedTrustManager;

import org.apache.http.HttpHost;
import org.apache.http.auth.AuthScope;
import org.apache.http.auth.UsernamePasswordCredentials;
import org.apache.http.client.CredentialsProvider;
import org.apache.http.impl.client.BasicCredentialsProvider;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.elasticsearch.client.RestClient;

import dev.langchain4j.data.segment.TextSegment;
import dev.langchain4j.store.embedding.EmbeddingStore;
import dev.langchain4j.store.embedding.elasticsearch.ElasticsearchEmbeddingStore;
import dev.langchain4j.store.embedding.inmemory.InMemoryEmbeddingStore;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Produces;

@ApplicationScoped
public class StoreFactory {

    @ConfigProperty(name = "quarkus.elasticsearch.hosts")
    String elasticsearchHosts;

    @ConfigProperty(name = "app.elasticsearch.password")
    String password;

    @ConfigProperty(name = "app.llm.storage")
    String storage;

    static InMemoryEmbeddingStore<TextSegment> embeddingStoreMemory = new InMemoryEmbeddingStore<>();

    @Produces
    public EmbeddingStore<TextSegment> elasticSearch() throws Exception {
        // RestClientHttpClient
        if ("memory".equals(storage)) {
            return embeddingStoreMemory;
        }

        final CredentialsProvider credentialsProvider = new BasicCredentialsProvider();
        credentialsProvider.setCredentials(AuthScope.ANY,
                new UsernamePasswordCredentials("elastic", password));
        SSLContext sslContext = SSLContext.getInstance("TLS");
        sslContext.init(null, new TrustManager[] { UnsafeX509ExtendedTrustManager.INSTANCE }, null);

        RestClient restClient = RestClient
                .builder(HttpHost.create(elasticsearchHosts))
                .setHttpClientConfigCallback(httpAsyncClientBuilder -> httpAsyncClientBuilder
                        .setSSLHostnameVerifier((s, sslSession) -> true)
                        .setSSLContext(sslContext)
                        .setDefaultCredentialsProvider(credentialsProvider)
                        )
                        
                .build();
        ElasticsearchEmbeddingStore store = ElasticsearchEmbeddingStore.builder()
                .restClient(restClient)
                .build();
        return store;

    }
}

final class UnsafeX509ExtendedTrustManager extends X509ExtendedTrustManager {

    public static final X509ExtendedTrustManager INSTANCE = new UnsafeX509ExtendedTrustManager();
    public static final X509Certificate[] EMPTY_CERTIFICATES = new X509Certificate[0];

    private UnsafeX509ExtendedTrustManager() {
    }

    public static X509ExtendedTrustManager getInstance() {
        return INSTANCE;
    }

    @Override
    public void checkClientTrusted(X509Certificate[] certificates, String authType) {

    }

    @Override
    public void checkClientTrusted(X509Certificate[] certificates, String authType, Socket socket) {

    }

    @Override
    public void checkClientTrusted(X509Certificate[] certificates, String authType, SSLEngine sslEngine) {

    }

    @Override
    public void checkServerTrusted(X509Certificate[] certificates, String authType) {

    }

    @Override
    public void checkServerTrusted(X509Certificate[] certificates, String authType, Socket socket) {

    }

    @Override
    public void checkServerTrusted(X509Certificate[] certificates, String authType, SSLEngine sslEngine) {

    }

    @Override
    public X509Certificate[] getAcceptedIssuers() {
        return EMPTY_CERTIFICATES;
    }

}
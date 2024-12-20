package org.acme;

import org.acme.model.GitlabEvent;
import org.apache.camel.Exchange;
import org.apache.camel.builder.RouteBuilder;
import org.apache.camel.model.rest.RestParamType;

public class MyRouteBuilder extends RouteBuilder {

    @Override
    public void configure() throws Exception {

        rest("/injest")
                .post()
                .description("register this endpoint as gitlab webwook")
                .type(GitlabEvent.class)
                .param().name("body").type(RestParamType.body).endParam()
                .consumes("application/json")
                
                .to("direct:downloadFiles")
                ;

        from("direct:downloadFiles")
            .unmarshal().json()
            .to("log:ingestBeforeSplitter?showBody=true&showHeaders=true")
            .split(method(new MyCustomSplitter(), "splitMe"))
            .to("log:ingestAfterSplitter?showBody=true&showHeaders=true")
            .to("direct:downloadFile")
            .end()
            .setBody(simple("Done"))
            .setHeader(Exchange.CONTENT_TYPE, constant("text/plain"))
            ;

        from("direct:downloadFile")
            .to("log:ingestDownloadFile?showBody=false&showHeaders=true")
            .removeHeaders("Camel*")
            .toD("${body}?httpmethod=GET")
            .to("bean:ingestion?method=ingest")
            ;


        rest("v1/chat/completions")
            .post()
            .to("direct:llm")
            ;

        from("direct:llm")
            .removeHeaders("CamelHttp*")
            .setHeader("Authorization", simple("Bearer {{app.llm.apiKey}}"))
            .to("log:entradaLLM?showHeaders=true")
            .choice()
                .when(simple("${header.app-source} == 'TechDocs'"))
                    .to("bean:chatBot?method=chat")
                // .when(simple("${header.foo} == 'TechDocs'"))
                //     .to("direct:chatBot")
                .otherwise()
                    .to("bean:chatBot?method=chatWithoutRAG")
            
            .to("log:saidaLLM")
            ;

    }
    
}

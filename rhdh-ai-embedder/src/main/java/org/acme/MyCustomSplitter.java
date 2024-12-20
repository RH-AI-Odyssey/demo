package org.acme;

import java.util.ArrayList;
import java.util.List;
import java.util.LinkedHashMap;
import java.util.Map;

import org.apache.camel.Exchange;


public class MyCustomSplitter {

    @SuppressWarnings({ "rawtypes", "unchecked" })
    public List splitMe(Exchange exchange) {
        Map json = (LinkedHashMap) exchange.getMessage().getBody();
        List<String> answer = new ArrayList<String>();
        String baseURI = ((Map)json.get("repository")).get("homepage").toString();
        for (Object commit : (List)json.get("commits")) {
            List<String> modifiedFiles = (List)((Map)commit).get("modified");
            //Example: https://gitlab.com/resthub/testes/-/raw/main/README.md
            modifiedFiles.forEach(m -> answer.add(baseURI+"/-/raw/main/"+m));

            List<String> addedFiles = (List)((Map)commit).get("added");
            //Example: https://gitlab.com/resthub/testes/-/raw/main/README.md
            addedFiles.forEach(m -> answer.add(baseURI+"/-/raw/main/"+m));
        }
        return answer;
    }

}

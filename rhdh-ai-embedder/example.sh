curl -X 'POST' \
  'http://localhost:8080/injest' \
  -H 'accept: */*' \
  -H 'Content-Type: application/json' \
  -d '{
  "commits": [
    {
      "modified": [
        "exhibitions.txt,
        "groups.txt",
        "vinicius.txt"
      ]
    }
  ],
  "repository": {
    "homepage": "https:gitlab.com/resthub/testes"
  }
}'
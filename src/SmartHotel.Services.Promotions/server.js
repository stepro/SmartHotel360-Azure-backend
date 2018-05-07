var express = require('express');

var app = express();

app.get('/api/:id', function (req, res) {
    var id = parseInt(req.params.id);
    if (!id) {
        res.status(500).send("Error");
    } else {
        res.status(200).send("0.05");
    }
});

var port = 80;
var server = app.listen(port, function () {
    console.log('Listening on port ' + port);
});

process.on("SIGINT", () => {
    process.exit(130 /* 128 + SIGINT */);
});

process.on("SIGTERM", () => {
    console.log("Terminating...");
    server.close();
});

var express = require('express');

var app = express();

app.get('/api/:id', function (req, res) {
    var hotelId = parseInt(req.params.id);
    if (hotelId < 0)  {                                                                       //|| isNaN(hotelId)) {
        res.status(400).send("Something's not right with Hotel ID");
    }
    else {
        var discount = applyPromotions(hotelId);
        res.status(200).send(discount);
    }
});

app.get('/', function (req, res) {
    res.status(200).send("hello from promotions");
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

/////////////////////////////////////////////////////////
function applyPromotions(hotelId) {
    if (hotelId < 0 || hotelId >= promotions.length) {
        return "0.0";
    }
    return promotions[hotelId];
}

var promotions=["0.05", "0.10", "0.12", "0.10", "0.03", "0.10", "0.12", "0.10", "0.03", "0.10", "0.12", "0.10", "0.03"];

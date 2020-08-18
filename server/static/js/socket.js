var WebSocket = WebSocket || window.WebSocket || window.MozWebSocket; 
var proto = {};
proto.dispatch = function (data, sz) {
    var TYPE = {
        "q" : "REQUEST",
        "s" : "RESPONSE",
    }
    var msg = data;
    if (typeof(msg) == "string") {
        msg = JSON.parse(data);
    }
    var type = TYPE[msg.t];
    if (!type) {
        return "UNKNOWN"
    }
    if (type == "RESPONSE") {
        return {type : type, session : msg.s, args : msg.d}
    }
    var session = msg.s
    var name = msg.n
    var args = msg.d
    if (!session) {
        return {type : type, name : name, args : args}
    }
    var response = function (s) {
        var msg = {
            t : "s",
            s : session,
            d : s,
        }
        return JSON.stringify(msg);
    }
    return {type : type, name : name, args : args, response : response}
}

proto.hostRequest = function (name, msg, session) {
    var req = {
        t : "q",
        s : session,
        n : name, 
        d : msg,
    }
    return JSON.stringify(req);
}

window.Socket = function () {
    this.session = 1;
    this.sessionContents = {};
    this.onMessages = [];
    this.status = "";
    this.url = "";
    this.state = {
        get : function () {
            if (this.ws) {
                return this.ws.readState;
            }
            return "";
        }
    }
    
    this.on = function (name, callback) {
        this.onMessages.push({name : name, callback : callback});
    }

    this.emit = function () {
        var name = arguments[0];
        var args = [];
        for (var i = 1; i < arguments.length; i++) {
            args.push(arguments[i]);
        }
        this.onMessages.forEach(function (item) {
            if (name != item.name) {
                return;
            }
            item.callback.apply(null, args);
        });
    }

    this.close = function () {
        if(this.ws) {
           this.ws.close();
           this.ws = null; 
        }
    }
    
    this.connect = function (url) {
        var self = this;
        this.url = url;
        var ws = new WebSocket(url)
        ws.binaryType = "arraybuffer";
        ws.onopen = function () {
            self.emit("onopen");
        }
        ws.onmessage = function (event) {
            self.emit("onmessage", event);
            var data = event.data;
            var args = self.dispatch(data);
            var type = args.type;
            if (type == "REQUEST") {
                self.emit(args.name, args.args);
            } else if (type == "RESPONSE") {
                var session = args.session;
                var sessionContents = self.sessionContents[session];
                self.sessionContents[session] = null;
                sessionContents.callback(args.args);
            }
        }
        ws.onclose = function () {
            self.emit("onclose");
            this.status = "close";
            this.close();
            console.log("WebSocket url " + url + " close!");
        }
        ws.onerror = function (err) {
            self.emit("onerror", err);
            console.log("WebSocket url " + url + " err " + err);
        }
        this.ws = ws;
    }

    this.request = function (name, msg, callback) {
        var session = this.session++;
        this.sessionContents[session] = {
            name : name,
            callback : callback
        }
        var data = this.hostRequest(name, msg, session);
        this.ws.send(data);
    }

    this.dispatch = function (strData) {
        var data = proto.dispatch(strData, strData.length);
        if (data.type == "REQUEST") {
            var name = data.name
        } else {
            var name = this.sessionContents[data.session].name
        }
        return (function () {
            console.log("ws res name:", name, ", data:", JSON.stringify(data.args));
            return data
        })()
    }

    this.hostRequest = function (name, args, session) {
        let data = proto.hostRequest(name, args, session);
        return (function () {
            console.log("ws req name:", name, ", data:", JSON.stringify(args));
            return data
        })()
    }
}

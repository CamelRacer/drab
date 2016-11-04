import {Socket} from "phoenix"
import uuid from "node-uuid"
import $ from "jquery"

export var Drab = {
  EVENTS: ["click", "change", "keyup", "keydown"],
  run: function(drab_return) {
    this.drab_return = drab_return
    this.self = this
    this.myid = uuid.v1()
    this.onload_launched = false,
    this.path = location.pathname

    // disable all the Drab-related objects
    // they will be re-enable on connection
    this.disable_drab_objects(true)

    let socket = new Socket("/drab/socket", {params: {token: window.userToken}})
    socket.connect()
    this.channel = socket.channel(`drab:${this.path}`, {path: this.path, drab_return: this.drab_return})
    this.channel.join()
      .receive("error", resp => { console.log("Unable to join", resp) })
      .receive("ok", resp => this.connected(resp, this))
  },

  disable_drab_objects: function(disable) {
    for (let ev of this.EVENTS) {
      $(`[drab-${ev}]`).prop('disabled', disable)
    }
  },

  connected: function(resp, him) {
    him.channel.on("onload", (message) => {
    })
    // // handler for "query" message from the server
    // him.channel.on("query", (message) => {
    //   let r = $(message.query)
    //   let query_output = [
    //     message.query,
    //     message.sender,
    //     $(message.query).map(() => {
    //       return eval(`$(this).${message.get_function}`)
    //     }).toArray()
    //   ]
    //   him.channel.push("query", {ok: query_output})
    // })
    // execjs sends ready JS partial to be run here
    him.channel.on("execjs", (message) => {
      // console.log(message.js)
      let query_output = [
        message.sender,
        eval(message.js)
      ]
      // console.log(query_output)
      him.channel.push("execjs", {ok: query_output})
    })

    // Drab Events
    function payload(who, event) {
      setid(who)
      return {
        // by default, we pass back some sender attributes
        id:   who.attr("id"),
        text: who.text(),
        html: who.html(),
        val:  who.val(),
        data: who.data(),
        drab_id: who.attr("drab-id"),
        event_function: who.attr(`drab-${event}`)
      }
    }
    function setid(whom) {
      whom.attr("drab-id", uuid.v1())
    }
    // TODO: after rejoin the even handler is doubled or tripled
    //       hacked with off(), bit I don't like it as a solution 
    for (let ev of this.EVENTS) {
      $(`[drab-${ev}]`).off(ev).on(ev, function(event) {
        him.channel.push("event", {event: ev, payload: payload($(this), ev)})
      })
    }

    // $("[drab-click]").off('click').on("click", function(event) {
    //   him.channel.push("event", {event: "click", payload: payload($(this), "click")})
    // })
    // $("[drab-change]").off('change').on("change", function(event) {
    //   him.channel.push("event", {event: "change", payload: payload($(this), "change")})
    // })
    // $("[drab-keyup]").off('keyup').on("keyup", function(event) {
    //   him.channel.push("event", {event: "keyup", payload: payload($(this), "keyup")})
    // })
    // $("[drab-keydown]").off('keydown').on("keydown", function(event) {
    //   him.channel.push("event", {event: "keydown", payload: payload($(this), "keydown")})
    // })

    // initialize onload on server side, just once
    if (!this.onload_launched) {
      this.onload_launched = true
      this.disable_drab_objects(false)
      him.channel.push("onload", null)
    }
  }
}

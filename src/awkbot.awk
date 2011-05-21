# awkbot
# ----------------------------------------------------------------------------- 
# "THE BEER-WARE LICENSE" (Revision 43) borrowed from FreeBSD's jail.c: 
# <tag@cpan.org> wrote this file.  As long as you retain this notice you 
# can do whatever you want with this stuff. If we meet some day, and you think 
# this stuff is worth it, you can buy me a beer in return.   Scott S. McCoy 
# -----------------------------------------------------------------------------

#use assert.awk
#use config.awk
#use trim.awk
#use log.awk

BEGIN {
    config_load("etc/awkbot.conf")

    assert(config("irc.username"), "username not specified in config")
    assert(config("irc.nickname"), "nickname not specified in config")
    assert(config("irc.altnick"), "altnick not specified in config")
    assert(config("irc.server"), "server not specified in config")
    assert(config("irc.port"), "port not specified in config")
}

function awkbot_init (	server,port,nick,user,name,logfile,loglevel) {
    # Set up the logger first, since everything else will try and write to it.
    kernel_load("logger.awk", "log")

    logfile  = config("logfile")
    loglevel = config("loglevel")

    if ("" != logfile) {
        kernel_send("log", "logfile", logfile)
    }

    if ("" != loglevel) {
        kernel_send("log", "level", "default", loglevel)
    }

    kernel_load("irc.awk", "irc")

    server = config("irc.server")
    port   = config("irc.port")

    nick   = config("irc.nickname")
    user   = config("irc.username")
    name   = config("irc.realname")

    kernel_listen("irc", "connected")
    kernel_listen("irc", "privmsg")
    kernel_listen("irc", "ctcp_version")

    kernel_send("irc", "server", server, port, nick, user, name)

    awkbot = nick
}

function awkbot_connected () {
    kernel_send("irc", "join", "#awkbot-test")
}

function awkbot_privmsg (recipient, nick, host, message     ,m,address,action) {
    # If the user wasn't speaking to awkbot directly (private message) then
    # determine who they were addressing in a channel (potentially awkbot)
    if (recipient == awkbot) {
        address = awkbot
    }
    else {
        m       = match(message, /:| /)
        address = substr(message, 1, m - 1)
        message = trim(substr(message, m + 1))
    }

    # The user wasn't addressing us, ignored.
    if (address != awkbot) {
        return debug("message addressed to %s, not %s", address, awkbot) 
    }

    # Echo.
    if (recipient == awkbot) {
        kernel_send("irc", "msg", nick, message)
    }
    else {
        kernel_send("irc", "msg", recipient, message)
    }
}

function awkbot_ctcp_version (recipient, nick, host) {
    debug("awkbot->ctcp_version(\"%s\", \"%s\", \"%s\")", \
          recipient, nick, host)

    kernel_send("irc", "reply", nick, "version", \
                "awkbot https://github.com/ssmccoy/awkbot")
}

# -----------------------------------------------------------------------------
# The dispatch table

"init"         == $1 { awkbot_init()                    }
"connected"    == $1 { awkbot_connected()               }
"privmsg"      == $1 { awkbot_privmsg($2,$3,$4,$5)      }
"ctcp_version" == $1 { awkbot_ctcp_version($2,$3,$4) }

# -----------------------------------------------------------------------------
# XXX The following is for reference only.  It is antiquated and will need to
# be removed.
function irc_handler_error () {
    reconnect()
}

function irc_handler_connect (  channel,key,msg) { 
    split(config("irc.channel"), channel)
    for (key in channel) irc_join("#" channel[key]) 

    msg = config("irc.startup")

    if (msg) irc_sockwrite(msg "\r\n")

    awkbot_db_status_connected(1)
}

function irc_handler_ctcp (nick, host, recipient, action, argument) {
    # Don't respond to channel ctcps
    if (recipient !~ /\#/) {
        if (tolower(action) == "version") {
            irc_ctcp_reply(nick, action, VERSION)
        }

        else if (tolower(action) == "ping") {
            irc_ctcp_reply(nick, action, argument)
        }
    }
}

func calc (expr ,result,bc) {
    bc = "bc -q"
    print "scale=10" |& bc
    print expr       |& bc
    print "quit"     |& bc
    bc |& getline result
    close(bc)

    # coerce to number
    return result + 0
}

function irc_handler_privmsg (nick, host, recipient, message, argc, arg  \
    ,direct,target,address,action,c_msg,larg,t,q,a,s)
{
    if (recipient ~ /^#/) target = recipient
    else                  target = nick

#    print "irc_handler_privmsg(", nick "," host "," recipient "," \
#        message "," argc ")" >> "debug.log"

    # A special case...
    if (substr(arg[1], 0, length(irc["nickname"])) == irc["nickname"] &&
            arg[1] !~ irc["nickname"] "\\+\\+")
    {
#        print "irc_handler_privmsg", "direct channel message" >> "debug.log"

        direct  = 1
        # Join the second word until the end as the cleaned message.
        c_msg   = join(arg, 2, argc + 1, OFS)

        # Remove the first item from the list of args...
        shift(arg)
    }
    else {
#        print "irc_handler_privmsg", "private message" >> "debug.log"

        direct  = (target != recipient)
        # It's either privmsg, or they're not talking to us, so the clean
        # message is the whole message.
        c_msg   = message
    }

    # Last arg is the arg count + 1
    larg = argc + 1

    # The "clean" message
#    print "irc_handler_privmsg", "cleaned message:", c_msg >> "debug.log"

    if (target == recipient) address = nick ": "
    else address = ""

    if (direct) {
#        print "The message was directed as me" >> "debug.log"

        if (arg[1] == "karma") {
#            print "irc_handler_privmsg", "command", "karma" >> "debug.log"
            awkbot_karma_get(target,arg[2])
        }
        else if (arg[1] == "forget") {
#            print "irc_handler_privmsg", "command", "forget" >> "debug.log"
            awkbot_db_forget(join(arg,2,argc,SUBSEP))
            irc_privmsg(target, address "what's a "join(arg,2,larg)"?")
        }
        else if (arg[2] == "is") {
#            print "irc_handler_privmsg", "command", "remember" >> "debug.log"
            awkbot_db_answer(arg[1], join(arg, 3, larg, " "))
            irc_privmsg(target, address "Okay")
        }
        # It's only numbers and stuff
        else if (c_msg ~ /^[0-9^.*+\/() -][0-9^.*+\/() -]*$/) {
#            print "irc_handler_privmsg", "command", "calc" >> "debug.log"
            irc_privmsg(target, address calc(c_msg)) 
        }
        else if (arg[1] == "uptime") {
#            print "irc_handler_privmsg", "command", "uptime" >> "debug.log"
            a = awkbot_db_uptime();
            irc_privmsg(target, address a)
        }
        else {
#            print "irc_handler_privmsg", "command", "QnA" >> "debug.log"

            # Portable equivilent of
            # q = gensub(/\?$/, "", "g", join(arg, 1, sizeof(arg), SUBSEP))
            q = join(arg, 1, larg, SUBSEP)
            gsub(/\?$/, "", q)

            if (a = awkbot_db_question(tolower(q))) {
                irc_privmsg(target, address a)
            }

#            print "irc_handler_privmsg", "QnA", "q:", q, "a:", a >> "debug.log"
        }
    }

    if (match(arg[1], /^(.*)\+\+$/)) {
        s = substr(arg[1], 1, length(arg[1]) - 2)

        if (s == nick) {
            irc_privmsg(target, address "changing your own karma is bad karma")
            awkbot_db_karma_dec(nick)
        }
        else {
            awkbot_db_karma_inc(s)
        }
    }
    if (match(arg[1], /^(.*)--$/)) {
        s = substr(arg[1], 1, length(arg[1]) - 2)

        if (s == nick) {
            irc_privmsg(target, address "don't be dumb")
            awkbot_db_karma_dec(nick)
        }
        else {
            awkbot_db_karma_dec(s)
        }
    }

    if (arg[1] == "awkdoc") {
        irc_privmsg(target, address "awkdoc is temporarily disabled")

#       if (arg[2]) {
#           irc_privmsg(target, address awkdoc(arg[2]))
#       }
#       else {
#           irc_privmsg(target, address "Usage is awkdoc < identifier >")
#       }
    }
    else if (arg[1] == "awkinfo") {
        if (arg[2]) {
            a = awkbot_db_info(arg[2])

            if (a) {
                irc_privmsg(target, address a)
            }
            else {
                irc_privmsg(target, address "I don't know anything about " \
                        arg[2])
            }
        }
        else {
            irc_privmsg(target, address "Usage is awkinfo < keyword >")
        }
    }
    else if (arg[1] == nick) {
        irc_privmsg(target, address "Talking about yourself, are we?")
    }
}

function awkbot_karma_get (reply_to,nickname     ,points)  {
    points = awkbot_db_karma(nickname)
    irc_privmsg(reply_to, sprintf("Karma for %s: %d points", nickname, points))
}

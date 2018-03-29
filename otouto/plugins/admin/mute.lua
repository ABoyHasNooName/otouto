local bindings = require('otouto.bindings')
local utilities = require('otouto.utilities')
local autils = require('otouto.autils')

local P = {}

function P:init(bot)
    self.triggers = utilities.triggers(bot.info.username, bot.config.cmd_pat)
        :t('mute', true).table
    self.command = 'mute'
    self.doc = "Mute a user or users indefinitely or for the time specified. \z
The duration can be specified before the reason.\
Examples:\
    /mute @foo @bar 8675309\
    2h30m No cursing on my Christian server.\
\
    [in reply] /mute 240"
    self.privilege = 2
    self.administration = true
    self.targeting = true
    self.duration = true
end

function P:action(bot, msg, _group, _user)
    local targets, reason, duration = autils.targets(bot, msg)

    -- Durations shorter than 30 seconds and longer than a leap year are
    -- interpreted as "forever" by the bot API.
    if duration and (duration > (366*24*60*60) or duration < 30) then
        duration = nil
    end

    local out_str, log_str
    if duration then
        out_str = ' has been muted for '.. utilities.tiem.format(duration) ..'.'
        log_str = 'Muted for ' .. utilities.tiem.format(duration)
    else
        out_str = ' has been muted.'
        log_str = 'Muted'
    end

    local output = {}
    local muted_users = {} -- Passed to the log function at the end.

    if targets then
        for _, id in ipairs(targets) do
            if tonumber(id) then
                local name = utilities.format_name(bot, id)

                if autils.rank(bot, id, msg.chat.id) > 1 then
                    table.insert(output,name..' is too privileged to be muted.')
                else
                    local a, b = bindings.restrictChatMember{
                        chat_id = msg.chat.id,
                        user_id = id,
                        until_date = duration and os.time() + duration,
                        can_send_messages = false
                    }
                    if not a then
                        table.insert(output, b.description .. ' (' .. id .. ')')
                    else
                        table.insert(output, name .. out_str)
                        table.insert(muted_users, id)
                    end
                end

            else
                table.insert(output, id)
            end
        end

    else
        table.insert(output, bot.config.errors.specify_targets)
    end

    utilities.send_reply(msg, table.concat(output, '\n'), 'html')
    if #muted_users > 0 then
        autils.log(bot, {
            chat_id = msg.chat.id,
            targets = muted_users,
            action = log_str,
            source_id = msg.from.id,
            reason = reason
        })
    end
end

return P
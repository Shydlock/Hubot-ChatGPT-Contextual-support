getInfo = (robot, messages, callback) ->
  data = JSON.stringify({
    model: "gpt-3.5-turbo",
    messages: messages
  })
  options =
    # don't verify server certificate against a CA, SCARY!
    rejectUnauthorized: false
  robot.http("https://api.openai.com/v1/chat/completions",options)
    .header('Accept', 'application/json')
    .header('Content-type', 'application/json')
    .header('Authorization','Bearer YOUR_OPENAI_KEY')
    .post(data) (err, res, body) ->
        callback(err, res, body)

module.exports = (robot) ->
  prompt = []
  record = ""
  del_tag = false
  total_tokens = 0
  max_tokens = 2800
  top_tokens = 4000

  robot.respond /(.*)/i, (msg)  ->
    tmp_prompt = prompt
    mes = msg.match[1]
    # msg.send "#{mes.length}"
    
    switch mes
      when '帮助', 'help'
        msg.send "聊天机器人使用介绍："
        msg.send "本机器人基于OpenAI最新发布的ChatGPT3.5版本的turbo接口实现"
        msg.send "直接发送文字即可开启聊天"
        msg.send "请注意：由于接口限制，聊天的上下文语境最多只能保留2000个汉字或4000个英文字母。因此，当出现相关提示时请使用命令`清除记录` / `清空记录` / `清除记忆` / `清空记忆`清除聊天上下文语境后继续使用"
        msg.send "当你不确定您当前的聊天字数或想要回顾聊天记录时可以通过`聊天记录`命令查看"
      when '清除记忆', '清空记忆', '清除记录', '清空记录'
        msg.send "你确定要清空我的记忆嘛，清空了我的记忆我就不记得你了"
        del_tag = true
      when '确定'
        prompt = []
        total_tokens = 0
        del_tag = false
        msg.send "我的记忆已经完全清空，快来开始新的对话吧 ~"
      when '不了','不','不要','撤销','否'
        del_tag = false
        msg.send "清除记忆操作已取消"
      when '聊天记录'
        tmp = ''
        mess = prompt
        msg.send "聊天记录「共占用 #{total_tokens} 个 token」："
        for item in mess 
          if item.role == "user"
            msg.send "Human: #{item.content}"
          if item.role == "assistant"
            respond = ''
            if item.content.startsWith '\n'
              r = item.content.split '\n'
              i = 0
              for item in r
                if i >= 2
                    respond = respond + item
                    if (i+1) != r.length
                        respond = respond + "\n"
                i = i + 1
            else
              respond = item.content
            msg.send "AI: #{respond}"
      else
        tmp = {
          role: "user",
          content: "#{mes}"
        }
        prompt = prompt.concat tmp
        mess = prompt
        
        getInfo robot, mess, (err, res, body) ->
          if res.statusCode isnt 200
            data = JSON.parse body

            msg.send "#{data.error.message}"
            if data.error.message.includes "This model's maximum context length is"
              msg.send "很抱歉，我的存储空间已经到达上限，请回复「清除/清空记忆/记录」清空我的记忆后开启一段崭新的对话"
          else
            data = JSON.parse body
            prompt = prompt.concat data.choices[0].message
            respond = ""
            if data.choices[0].message.content.startsWith '\n'
              r = data.choices[0].message.content.split '\n'
              
              i = 0
              for item in r
                if i >= 2
                    respond = respond + item
                    if (i+1) != r.length
                        respond = respond + "\n"
                i = i + 1
            else
              respond = data.choices[0].message.content
            try
              respond = respond.replace /\$\$(.*?)\$\$/g, '\\[$1\\]'
            catch Error
              e = Error
            try
              respond = respond.replace /\$(.*?)\$/g,'\n\n\\[$1\\]'
            catch Error
              e = Error
            total_tokens = data.usage.total_tokens
            msg.send "#{respond}"
                
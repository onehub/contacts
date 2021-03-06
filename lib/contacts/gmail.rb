require "json"

class Contacts
  class Gmail < Base
    URL                 = "https://mail.google.com/mail/"
    LOGIN_URL           = "https://www.google.com/accounts/ServiceLoginAuth"
    LOGIN_REFERER_URL   = "https://www.google.com/accounts/ServiceLogin?service=mail&passive=true&rm=false&continue=http%3A%2F%2Fmail.google.com%2Fmail%3Fui%3Dhtml%26zy%3Dl&ltmpl=yj_blanco&ltmplcache=2&hl=en"
    CONTACT_LIST_URL    = "https://mail.google.com/mail/contacts/data/contacts?thumb=true&show=ALL&enums=true&psort=Name&max=10000&out=js&rf=&jsx=true"
    PROTOCOL_ERROR      = "Gmail has changed its protocols, please upgrade this library first. If that does not work, contact lucas@rufy.com with this error"
    
    def real_connect
      postdata =  "ltmpl=yj_blanco"
      postdata += "&continue=%s" % CGI.escape(URL)
      postdata += "&ltmplcache=2"
      postdata += "&service=mail"
      postdata += "&rm=false"
      postdata += "&ltmpl=yj_blanco"
      postdata += "&hl=en"
      postdata += "&Email=%s" % CGI.escape(login)
      postdata += "&Passwd=%s" % CGI.escape(password)
      postdata += "&rmShown=1"
      postdata += "&null=Sign+in"
            
      time =      Time.now.to_i
      time_past = Time.now.to_i - 8 - rand(12)
      cookie =    "GMAIL_LOGIN=T#{time_past}/#{time_past}/#{time}"
      
      data, resp, cookies, forward, old_url = post(LOGIN_URL, postdata, cookie, LOGIN_REFERER_URL) + [LOGIN_URL]
      
      cookies = remove_cookie("GMAIL_LOGIN", cookies)
      
      if data.index("Username and password do not match")
        raise AuthenticationError, "Username and password do not match"
      elsif data.index("Required field must not be blank")
        raise AuthenticationError, "Login and password must not be blank"
      elsif data.index("errormsg_0_logincaptcha")
        raise AuthenticationError, "Captcha error"
      elsif data.index("Invalid request")
        raise ConnectionError, PROTOCOL_ERROR
      elsif cookies == ""
        raise ConnectionError, PROTOCOL_ERROR
      end
      
      cookies = remove_cookie("LSID", cookies)
      cookies = remove_cookie("GV", cookies)

      @cookies = cookies
    end
    
  private
    
    def parse(data, options)
      data.gsub!(/^while \(true\); &&&START&&&/, '')
      data.gsub!(/ &&&END&&&$/, '')
      data.gsub!(/\t/, ' ') # tabs in the note field cause errors with JSON.parse

      @contacts = JSON.parse(data)['Body']['Contacts'] || {}

      # Determine in which format to return the data.
      
      # Return the full JSON Hash. 
      return @contacts if(options[:details])

      # Default format.
      # ['Name', 'Email1', 'Email2', ...]
      @contacts = @contacts.delete_if {|c| c["Emails"].nil?}.map do |c|
        name, emails, company = c.values_at "Name", "Emails", "Company"
        emails = emails.first.values
        [name, emails, company].flatten
      end
    end
    
  end

  TYPES[:gmail] = Gmail
end

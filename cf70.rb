# CF 4.0

require "addressable/uri"
require 'sinatra'
require "sinatra/multi_route"
require 'json'
require 'csv'
require 'uuidtools'
require 'twilio-ruby'

require './librarian.rb'

IP = "0.0.0.0"
PORT = 7009
GAME_CYCLE = 600
REFILL = 480
ENERGY_CAPACITY = 5
TIME_DIFFERENCE_UPPER_BOUND = 8 * 60 * 60 # secs
TIME_DIFFERENCE_LOWER_BOUND = 5 * 60 # secs
INITIAL_COINS = 0
PLAY_MAX_BET = 200
GUESS_MAX_BET = 200

set :bind, '0.0.0.0'
set :port, PORT

enable :sessions

def set_interval(delay, name)
  @@last_time_modified[name] = Time.now
  @@threads[name] = Thread.new do
    loop do
      sleep delay
      if @@energy_left[name] < ENERGY_CAPACITY
         @@energy_left[name] = @@energy_left[name] + 1
         @@last_time_modified[name] = Time.now
      end
    end
  end
end

def import_questions
  
  @@categories = Hash.new
  @@questions = Array.new
  
  CSV.foreach("questions.csv") do |row|
    # question, value, categ, dim, att
    @@questions << row[0]
    @@categories[row[0]] = {"value"=>row[1].to_i, "categ"=>row[2], "dim"=>row[3], "att"=>row[4]}
  end

  @@questions.shuffle!
  # @@questions.shuffle!
  # CSV.open("suffled_questions.csv", "wb") do |csv|
  #   @@questions.each do |i|
  #     csv << i
  #   end
  # end
end

# run after import_questions
def extract_categ
  categories = @@categories.values.map{|hash| hash["categ"]}.uniq
  categories.each do |categ|
    CATEGORIES[categ] = Array.new
    dims = @@categories.values.select{|hash| hash["categ"] == categ}.map{|hash| hash["dim"]}.uniq
    dims.each do |dim|
        CATEGORIES[categ] << dim
    end                              
  end
end

def import_names
  # @@names = ["John", "Peter", "Rachel Williams", "Daniel", "Sean", "中文 名字"]
  
  @@names = Array.new
  CSV.foreach("names.csv") do |row|
    @@names << row[0]
  end
end

def configure_Twilio
  account_sid = "ACea251252af736aa1ea64f234945d840b"
  auth_token = "35822c755833de8c04bf3f7a1bdc9ce7"

  @@client = Twilio::REST::Client.new account_sid, auth_token
end


# assuming names and questions are set
# format: [tester, question, chosen option, unchosen option]
def initialize_record

  @@tester_progress = Array.new(@@names.count, -1)
  @@phone_number = Hash.new
  # @@sharing_queue = Hash.new

  #Iru
  # @@people_asks = Hash.new
  # @@record_comments = Hash.new
  # @@record_asks = Hash.new
  # @@asking_queue = Hash.new
  # @@last_played = Hash.new
  @@questions_left = Hash.new
  @@energy_left = Hash.new
  @@started_playing = Hash.new
  @@threads = Hash.new
  @@last_time_modified = Hash.new
  @@coins = Hash.new
  @@unlocked = Hash.new
  @@others_comments = Hash.new
  # @@bundle_played = Hash.new

  #cf70
  # @@generated_bundles = Hash.new
  @@level = Hash.new
  @@progress = Hash.new
  @@gems = Hash.new
  @@unlocked_uuid_index = Hash.new
  @@data_to_w_r = ["categories", "spiderweb_buffer","logged_in","view_report","unlock_someone", "play_others","play_answer","view_rankings","use_gems","wins", "losses", "level", "progress", "gems", "unlocked_uuid_index", "coins"]
  @@wins = Hash.new
  @@losses = Hash.new

  @@view_report = Hash.new
  @@play_others = Hash.new
  @@play_answer = Hash.new
  @@view_rankings = Hash.new
  @@use_gems = Hash.new
  @@unlock_someone = Hash.new
  @@logged_in = Hash.new

  @@spiderweb_buffer = Hash.new

  @@record = Array.new 
  prng = Random.new(1234)
  @@score = Array.new(@@names.count){|i|Array.new(@@questions.count,prng.rand(2))}

  @@librarian = Librarian.new(@@names)
end

def initialize_independent_urls
  @@independent_ids = Hash.new
  prng = Random.new(1234)
  @@names.each do |name|
     id = (prng.rand(100000000)).to_s
     @@independent_ids[id] = name
  end

  @@independent_ids.each do |id, name|
    puts "%s->\n%s/?id=%s" % [name, URL, id]
  end

  File.open("private_links.txt", 'w') do |file|
    file.write "Private links:\n"
    @@independent_ids.each do |id, name|
      file.write "%s -> %s/?id=%s\n" % [name, URL, id]
    end
  end
end

def initilize_variables
  @@names.each do |name|
    @@coins[name] = INITIAL_COINS
    @@level[name] = 1
    @@energy_left[name] = ENERGY_CAPACITY
    @@progress[name] = 0
    @@gems[name] = 0
    @@wins[name] = 0
    @@losses[name] = 0
    @@view_report[name] = Array.new
    @@play_others[name] = Array.new
    @@play_answer[name] = Array.new
    @@view_rankings[name] = Array.new
    @@use_gems[name] = Array.new
    @@unlock_someone[name] = Array.new
    @@logged_in[name] = Array.new
  end
end



configure do
  puts "Configuring..."
  URL = "http://%s:%s" % [IP, PORT.to_s]

  import_questions
  import_names
  initialize_record
  configure_Twilio
  initilize_variables
  initialize_independent_urls

  CATEGORIES = Hash.new
  extract_categ
  
end

=begin
def render_lobby
  if @@last_played[session[:tester]] == nil
      @secs_to_play = "PLAY GAME! 10 left"
  else
      if @@questions_left[session[:tester]] != nil
         @secs_to_play = "PLAY GAME! "+ @@questions_left[session[:tester]].to_s + " left"
      else
         @secs_since = Time.now - @@last_played[session[:tester]]
         if @secs_since.to_i > GAME_CYCLE
             @secs_to_play = "PLAY GAME! 10 left"
         else
             temp = GAME_CYCLE - @secs_since.to_i
             @secs_to_play = temp.to_s
         end
      end
  end
  erb :lobby
end
=end


def clear_session
    session[:choose] = nil
    session[:bundle] = nil
    session[:option0] = nil
    session[:option1] = nil
    session[:question] = nil
    session[:round] = nil
    session[:guesswhom] = nil
    session[:correct_history] = nil
    session[:xp_to_add] = nil
    session[:skippedquestions] = nil
    session[:bettingleft] = nil
end


def add_new_player
  @@names.each do |name|
    if @@coins[name] == nil then @@coins[name] = INITIAL_COINS end
    if @@level[name] == nil then @@level[name] = 1 end
    if @@energy_left[name] == nil then @@energy_left[name] = ENERGY_CAPACITY end
    if @@progress[name] == nil then @@progress[name] = 0 end
    if @@gems[name] == nil then @@gems[name] = 0 end
    if @@wins[name] == nil then @@wins[name] = 0 end
    if @@losses[name] == nil then @@losses[name] = 0 end
    if @@view_report[name] == nil then @@view_report[name] = Array.new end
    if @@play_others[name] == nil then @@play_others[name] = Array.new end
    if @@play_answer[name] == nil then @@play_answer[name] = Array.new end
    if @@view_rankings[name] == nil then @@view_rankings[name] = Array.new end
    if @@use_gems[name] == nil then @@use_gems[name] = Array.new end
    if @@unlock_someone[name] == nil then @@unlock_someone[name] = Array.new end
    if @@logged_in[name] == nil then @@logged_in[name] = Array.new end

    @@librarian.add_player name
  end
end


route :get, :post, '/home' do
  if params["name"]
    puts "name: " + params["name"]
    @@names << params["name"] unless @@names.include? params["name"]
    
    add_new_player

    session[:tester] = params["name"]
  end
  if @@started_playing[session[:tester]] == nil
    set_interval(REFILL, session[:tester])
    @@started_playing[session[:tester]] = TRUE
  end
  @@logged_in[session[:tester]] << Time.now
  erb :home
end

get '/' do
  # if params[:id] == nil
    erb :login
  # else
  #   erb :tel
  # end
  # Who are you?
  #erb :home
  # if params[:id]
  #    id = params[:id]
  #    session[:tester] = @@independent_ids[id]
  # end 
  # puts "name: "+session[:tester]
  # clear_session
  # redirect to('/tel'), 307
end


get '/tel' do
  session[:stage] = "tel"

  ##hacking to play
  puts params[:num] 
  if params[:num] == "1"
    session[:tester] = "Iru Wang"
  elsif params[:num] == "2"
    session[:tester] = "Chiu-Ho Lin"
  else
    session[:tester] = "Wen Shaw"
  end
  @@names << "Iru Wang"
  @@names << "Chiu-Ho Lin"
  @@names << "Wen Shaw"
  add_new_player
  ###end hack

  @current_tester = session[:tester]  
  erb :tel
end

# post '/welcome' do
#   @current_tester = session[:tester]

#   if session[:stage] == "tel"
#     session[:stage] = nil
#     if (@@phone_number[@current_tester] == nil) or 
#        (params[:skip] != "yes")

#       phone_number = params[:phone_number]

#       @@phone_number[@current_tester] = phone_number  
#     end
#   end
#   if @@started_playing[session[:tester]] == nil
#      set_interval(REFILL, session[:tester])
#      @@started_playing[session[:tester]] = TRUE
#   end
#   @@logged_in[session[:tester]] << Time.now
#   redirect to('/home'), 307
# end

post '/choose_categ' do
  erb :choose_categ
end

post '/choose_people' do
  session[:categ] = params[:categ]
  @@play_answer[session[:tester]] << Time.now

  if @@energy_left[session[:tester]] > 0
     @@energy_left[session[:tester]] = @@energy_left[session[:tester]] - 1
     if @@energy_left[session[:tester]] == 4
        Thread.kill(@@threads[session[:tester]])
        set_interval(REFILL, session[:tester])
     end
  end

  prng = Random.new
  @initial_first = @@names[prng.rand(@@names.count)]
  @initial_second = @@names[prng.rand(@@names.count)]
  @shuffle_first = @@names[prng.rand(@@names.count)]
  @shuffle_second = @@names[prng.rand(@@names.count)]
  while @initial_first == session[:tester] do
    @initial_first = @@names[prng.rand(@@names.count)]
  end
  while @initial_second == @initial_first or @initial_second == session[:tester]
    @initial_second = @@names[prng.rand(@@names.count)]
  end
  while @shuffle_first == session[:tester] do
    @shuffle_first = @@names[prng.rand(@@names.count)]
  end
  while @shuffle_second == @shuffle_first or @shuffle_second == session[:tester]
    @shuffle_second = @@names[prng.rand(@@names.count)]
  end
  erb :choose_people
end

post '/choose_answer' do

  if session[:choose] == nil
    session[:choose] = 1
    session[:bundle] = Array.new
  else
    session[:choose] = session[:choose] + 1
  end
  if params[:option0]
    session[:option0] = params[:option0]
  end
  if params[:option1]
    session[:option1] = params[:option1]
  end
  if params[:question]
    session[:question] = params[:question]
  end

  # if params[:betting]
  #   puts "betting"
  #   puts params[:betting]
    
  # end

  prng = Random.new
  if params[:answer] and params[:betting]
     quiz = Hash.new
     quiz["question"] = session[:question]
     quiz["option0"] = session[:option0]
     quiz["option1"] = session[:option1]
     quiz["answer"] = params[:answer]
     quiz["time"] = Time.now

     @@coins[session[:tester]] -= params[:betting].to_i
     quiz["bet"] = params[:betting].to_i
     quiz["done"] = false
     session[:bundle] << quiz
  end

  if session[:choose] == 4
    
    @@librarian.create_parcel(session[:tester], session[:bundle])
    clear_session
    redirect to('/choose_ending'), 307
  end
  prng = Random.new
  question = @@questions[prng.rand(@@questions.count)]
  while already_exists(question, session[:bundle])
    question = @@questions[prng.rand(@@questions.count)]
  end
  session[:question] = question
  session[:bettingleft] = (@@coins[session[:tester]] < PLAY_MAX_BET)? @@coins[session[:tester]] : PLAY_MAX_BET
  erb :choose_answer
end

def already_exists(question, current_array)
  current_array.each do |quiz|
     if question == quiz["question"]
      return true
     end
  end
  # if session[:skippedquestions]
  #   session[:skippedquestions].each do |skippedquestion|
  #     if question == skippedquestion
  #       return true
  #     end
  #   end
  # end
  return false
end

def get_XP_needed(name)
  level = @@level[name]
  return level*100
end

def addupXP(value, name)
  xpneeded = get_XP_needed(name)
  progress = @@progress[name]
  xpgot = progress*xpneeded/100
  if xpgot + value >= xpneeded
    @@progress[name] = 100
    session[:xp_to_add] = xpgot + value - xpneeded
  else
    @@progress[name] = (100*((xpgot + value).to_f/xpneeded.to_f)).ceil
  end
end

post '/choose_ending' do
  @@coins[session[:tester]] = @@coins[session[:tester]] + 100

  # addupXP(100, session[:tester])

  erb :choose_ending
end

post '/finish_choose' do
  # if session[:xp_to_add]
  #   redirect to('/level_up'), 307
  # end
  redirect to('/home'), 307
end

post '/level_up' do
  @@energy_left[session[:tester]] = ENERGY_CAPACITY
  xp_to_add = session[:xp_to_add]
  @@level[session[:tester]] = @@level[session[:tester]] + 1
  xp_needed = get_XP_needed(session[:tester])
  @@progress[session[:tester]] = (100*(xp_to_add.to_f/xp_needed.to_f)).floor
  @@gems[session[:tester]] =  @@gems[session[:tester]] + 1
  clear_session
  erb :level_up
end

post '/refill' do
  @@use_gems[session[:tester]] << Time.now

  session[:tester] = params[:tester]
  @@energy_left[session[:tester]] = ENERGY_CAPACITY
  @@gems[session[:tester]] = @@gems[session[:tester]] - 1
  redirect to('/home'), 307
end


def normalize_score scores
  res = Hash.new
  multiplier = 0.0333333
  scores.each{|key, value| 
    if ["S", "R", "P"].include? key
      res[key] = Math.atan(multiplier * value.to_f)/(Math::PI) + 0.5
    else
      res[key] = value
    end
  }
  return res
end

#  tan(0.25 * PI)/30 = m => m = 0.033
def sec_to_units seconds
  mm, ss = seconds.divmod(60)
  hh, mm = mm.divmod(60)
  dd, hh = hh.divmod(24)
  if dd > 0 
    return "%d days, %d hours ago" % [dd, hh]
  elsif hh > 0
    return "%d hours, %d mins ago" % [hh, mm]  
  else
    return "%d mins ago" % [mm]  
  end
end

route :get, :post, '/view_my_report' do
  @@view_report[session[:tester]] << Time.now

  @my_questions = @@librarian.get_questions_of(session[:tester])

  @my_questions.shuffle!

  #-------- Below is about calculating the spider web! --------#
  # @@generated_bundles[name] = [
  #                              [uuid, [{qustion:xx, option0:xx, option1:xx, answer:xx, time:xx}, 
  #                                      {qustion:xx, option0:xx, option1:xx, answer:xx, time:xx},
  #                                      {qustion:xx, option0:xx, option1:xx, answer:xx, time:xx}]]
  #                             ]


  # quiz = {qustion:xx, option0:xx, option1:xx, answer:xx, time:xx}
  # 
  # bundle = [{qustion:xx, option0:xx, option1:xx, answer:xx, time:xx}, 
            # {qustion:xx, option0:xx, option1:xx, answer:xx, time:xx},
            # {qustion:xx, option0:xx, option1:xx, answer:xx, time:xx}]
  # 
  # parcel = [uuid, [{qustion:xx, option0:xx, option1:xx, answer:xx, time:xx}, 
                  #  {qustion:xx, option0:xx, option1:xx, answer:xx, time:xx},
                  #  {qustion:xx, option0:xx, option1:xx, answer:xx, time:xx}]]

  @name = session[:tester]

  if @@spiderweb_buffer[@name] == nil
    @@spiderweb_buffer[@name] = Hash.new
    @@spiderweb_buffer[@name]["old"] = {"S"=>0.5, "P"=>0.5, "R"=>0.5, "time"=>Time.now}
    @@spiderweb_buffer[@name]["new"] = {"S"=>0.5, "P"=>0.5, "R"=>0.5, "time"=>Time.now}
  end

  @scores = {"S"=>0, "P"=>0, "R"=>0, "time"=>Time.now,
             "detail" => {"S"=>Hash.new, "P"=>Hash.new, "R"=>Hash.new}
            }

  # first flatten the parcels to an array of quizes only 
  relevants = @@librarian.get_relevant_quizzes(@name)

  # relevants = @@generated_bundles.values.flatten(1).map{ |parcel| parcel[1]}.flatten.
  #              select{|quiz| (quiz["option0"] == @name) or (quiz["option1"] == @name)}
  
  
  CATEGORIES.each do |categ, dims|
    dims.each do |dim|
        @scores["detail"][categ][dim] = 0.0
    end                              
  end

  relevants.each do |quiz|
    value     = @@categories[quiz["question"]]["value"]
    category  = @@categories[quiz["question"]]["categ"]
    dim       = @@categories[quiz["question"]]["dim"]
    # att       = @@categories[quiz["question"]]["att"]

    another_option = (quiz["option1"] == @name) ? quiz["option0"] : quiz["option1"]
    if quiz["answer"] == @name      
      @scores[category] += value
      @scores["detail"][category][dim] += value  

    elsif quiz["answer"] == another_option
      @scores[category] -= value
      @scores["detail"][category][dim] -= value
      
    end
  end
  
  puts "score before"
  puts @scores.inspect
  @scores = normalize_score @scores
  
  puts "score after"
  puts @scores.inspect

  time_diff_w_old = @scores["time"] - @@spiderweb_buffer[@name]["old"]["time"]
  time_diff_w_new = @scores["time"] - @@spiderweb_buffer[@name]["new"]["time"]

  # First rule: Never too old
  if time_diff_w_old > TIME_DIFFERENCE_UPPER_BOUND
    @@spiderweb_buffer[@name]["old"] = @@spiderweb_buffer[@name]["new"]
  # Second rule: Never too new
  elsif time_diff_w_new < TIME_DIFFERENCE_LOWER_BOUND

  else
    # Third rule: The one with larger difference stays
    diff_w_old = (@scores["S"] - @@spiderweb_buffer[@name]["old"]["S"]).abs + 
                 (@scores["P"] - @@spiderweb_buffer[@name]["old"]["P"]).abs + 
                 (@scores["R"] - @@spiderweb_buffer[@name]["old"]["R"]).abs

    diff_w_new = (@scores["S"] - @@spiderweb_buffer[@name]["new"]["S"]).abs + 
                 (@scores["P"] - @@spiderweb_buffer[@name]["new"]["P"]).abs + 
                 (@scores["R"] - @@spiderweb_buffer[@name]["new"]["R"]).abs

    if diff_w_new > diff_w_old
      @@spiderweb_buffer[@name]["old"] = @@spiderweb_buffer[@name]["new"]
    end
  end
  @@spiderweb_buffer[@name]["new"] = @scores

  @time_difference = sec_to_units(@@spiderweb_buffer[@name]["new"]["time"] - @@spiderweb_buffer[@name]["old"]["time"])
  @oldR = @@spiderweb_buffer[@name]["old"]["R"]
  @oldP = @@spiderweb_buffer[@name]["old"]["P"]
  @oldS = @@spiderweb_buffer[@name]["old"]["S"]
  @newR = @@spiderweb_buffer[@name]["new"]["R"]
  @newP = @@spiderweb_buffer[@name]["new"]["P"]
  @newS = @@spiderweb_buffer[@name]["new"]["S"]

  @contributors = collect_contributors(@name)

  @guesser_questions = @@librarian.get_guesser_questions(@name)
  erb :my_report
end

post '/choose_guess_categ' do
  erb :choose_guess_categ
end

post '/choose_guess_people' do
  erb :choose_guess_people
end

post '/play' do
  @@play_others[session[:tester]] << Time.now

  if session[:round] == nil
    @@coins[session[:tester]] -= 50
    session[:round] = 1
    session[:correct_history] = Array.new
  else
    session[:round] += 1
  end

  # start the guessing
  if params[:uuid]
    name, bundle = @@librarian.get_bundle_by_uuid(params[:uuid])
    session[:guesswhom], session[:bundle] = name, bundle
    @@librarian.just_played(session[:tester], params[:uuid])
  end

  # in the middle of guessing
  if params[:correct]
    session[:correct_history] << params[:correct]
    if params[:betting]
        if params[:correct] == "true"
          @@coins[session[:tester]] += params[:betting].to_i
        else
          @@coins[session[:tester]] -= params[:betting].to_i
        end
    end
  end

  if session[:round] == 4
    redirect to('/result'), 307
  end
  @question = session[:bundle][session[:round]-1]["question"]
  @option0 = session[:bundle][session[:round]-1]["option0"]
  @option1 = session[:bundle][session[:round]-1]["option1"]
  @answer = session[:bundle][session[:round]-1]["answer"]
  session[:bettingleft] = (@@coins[session[:tester]] < GUESS_MAX_BET)? @@coins[session[:tester]] : GUESS_MAX_BET
  erb :play
end

post '/result' do
  @win = 0
  session[:correct_history].each do |value|
    if value == "true"
       @win += 1
    end
  end
  if @win == 0
    @reward = 10
  elsif @win == 1
    @reward = 20
  elsif @win == 2
    @reward = 40
  else
    @reward = 50
  end
  @@coins[session[:tester]] += @reward

  addupXP(@reward, session[:tester])
    
  if @win >= 2
    @correct = true
    @@wins[session[:tester]] += 1
    @@librarian.record_win(session[:tester], session[:bundle], session[:guesswhom], session[:correct_history])
  else
    @correct = false
    @@losses[session[:tester]] += 1
  end
  erb :result
end


route :get, :post, '/rankings' do
  @@view_rankings[session[:tester]] << Time.now

  if session[:xp_to_add]
    redirect to('/level_up'), 307
  end

  @sortedLevelArray = @@level.sort_by {|key,value| value}
  clear_session
  erb :rankings
end

post '/start' do
  if @@energy_left[session[:tester]] > 0
     @@energy_left[session[:tester]] = @@energy_left[session[:tester]] - 1
     if @@energy_left[session[:tester]] == 4
        Thread.kill(@@threads[session[:tester]])
        set_interval(REFILL, session[:tester])
     end
  end
  @@questions_left[session[:tester]] = 5
  @current_tester = session[:tester]
  #if @@questions_left[session[:tester]] == nil
  #    @@questions_left[session[:tester]] = 10;
  #    @@last_played[session[:tester]] = Time.now
  #end


  #if session[:stage] == "tel"
  #  session[:stage] = nil
  #  if (@@phone_number[@current_tester] == nil) or 
  #     (params[:skip] != "yes")

  #    phone_number = params[:phone_number]

  #    @@client.account.messages.create(
  #      :from => '+17183955452',
  #      :to => phone_number,
  #      :body => 'Welcome, %s! Ready to play the game? :-)' % @current_tester
  #    )

  #    @@phone_number[@current_tester] = phone_number  
  #  end
  #end

  name_index = @@names.index(@current_tester)
  if @@tester_progress[name_index] != -1
    @current_question = @@questions[@@tester_progress[name_index]]
    
  else
    @current_question = @@questions.sample
    question_index = @@questions.index(@current_question)
    @@tester_progress[name_index] = question_index
  
  end

  if session[:option0] and session[:option1]
    @current_options = [session[:option0], session[:option1]]
  else
    @current_options = (@@names - [@current_tester]).sample(2)  
  end

  session[:question] = @current_question
  session[:option0] = @current_options[0]
  session[:option1] = @current_options[1]
  name_index_0 = @@names.index(@current_options[0])
  name_index_1 = @@names.index(@current_options[1])
  current_question_index = @@questions.index(@current_question)
  @option_0_vote = @@score[name_index_0][current_question_index]
  @option_1_vote = @@score[name_index_1][current_question_index]


  if @@questions_left[session[:tester]] == 0
    @@questions_left[session[:tester]] = nil
    redirect to('/lobby'), 307
  else
    erb :question
  end
end

post '/next' do
  @@questions_left[session[:tester]] = @@questions_left[session[:tester]] -1
  
  prev_options = [session[:option0], session[:option1]]
  prev_question = session[:question]
  @current_tester = session[:tester]
  
  answer = params[:chosenName]
  #unanswer = (prev_options[0] == answer) ? prev_options[1] : prev_options[0]

  # record the result
  @@record << [@current_tester, prev_question, answer, prev_options[0], prev_options[1], Time.now]

  subject_index = @@names.index(answer)
  if subject_index != nil
    question_index = @@questions.index(prev_question)
    if question_index != nil
      @@score[subject_index][question_index] += 1
    end
  end

  new_index = @@questions.index(prev_question) + 1
  new_index = 0 if new_index >= (@@questions.count)

  @current_question = @@questions[new_index]
  name_index = @@names.index(@current_tester)
  @@tester_progress[name_index] = new_index
  @current_options = (@@names - [@current_tester]).sample(2)

  session[:question] = @current_question
  session[:option0] = @current_options[0]
  session[:option1] = @current_options[1]
  name_index_0 = @@names.index(@current_options[0])
  name_index_1 = @@names.index(@current_options[1])
  current_question_index = @@questions.index(@current_question)
  @option_0_vote = @@score[name_index_0][current_question_index]
  @option_1_vote = @@score[name_index_1][current_question_index]
  
  if @@questions_left[session[:tester]] == 0
    @@questions_left[session[:tester]] = nil
    @@coins[session[:tester]] = @@coins[session[:tester]] + 10
    redirect to('/lobby'), 307
  else   
    erb :question
  end
end

post "/unlockGuesser" do
  puts params[:uuid]
  @@coins[session[:tester]] = @@coins[session[:tester]] - 300
  @@librarian.unlock_guesser(session[:tester], params[:uuid])
  status 200
  body ''
end


post "/unlock" do
  @@unlock_someone[session[:tester]] << Time.now

  @current_tester = params[:tester]
  uuid = params[:uuid]
  index = params[:index]
  index_array = Array.new
  index_array << uuid
  index_array << index
  @@coins[@current_tester] = @@coins[@current_tester] - 300
  if @@unlocked_uuid_index[@current_tester] == nil
      uuid_index_array = Array.new
      uuid_index_array << index_array
      @@unlocked_uuid_index[@current_tester] = uuid_index_array
  else
      uuid_index_array = @@unlocked_uuid_index[@current_tester]
      uuid_index_array << index_array
  end
  status 200
  body ''
end

post "/shuffle_people" do
  @@unlock_someone[session[:tester]] << Time.now
  @@coins[session[:tester]] = params[:coinsLeft].to_i
  
  status 200
  body ''
end

post "/shuffle_question" do
  @@coins[session[:tester]] = params[:coinsLeft].to_i
  if session[:skippedquestions]
    session[:skippedquestions] << params[:oldq]
  else
    session[:skippedquestions] = Array.new
    session[:skippedquestions] << params[:oldq]
  end
  prng = Random.new
  loop do 
      @question = @@questions[prng.rand(@@questions.count)]     
      break if !already_exists(@question, session[:bundle])
  end 
  puts @question
  status 200
  body @question
end


get "/record_all_data" do
  @@data_to_w_r.each do |name| 
    File.open(name + ".txt", 'w') do |file|
      file.write(eval("@@" + name).to_json)
    end
  end
  status 200
  body ''
end

get "/read_all_data" do
  @@data_to_w_r.each do |name|
    File.open(name + ".txt", 'r') do |file|
      temp = file.read
      code = "@@" + name + "=" + "JSON.parse(temp)"
      eval(code)
    end
  end
  status 200
  body ''
end

def calculate_slowdown
  people_in_slowdown = Array.new(@@names.count)
  looping_stopper = Array.new(@@names.count, false)
  time_now = Time.now

  @@record.reverse.each do |record| 
    index = @@names.index(record[0])
    unless looping_stopper[index]    
      looping_stopper[index] = true
      people_in_slowdown[index] = (time_now - record[5]) > @slowdown_minutes * 60
      @slowdown_people << record[0] if people_in_slowdown[index]
    end

    if looping_stopper.index(false) == nil
      break
    end
  end
end

get '/admin' do
  @slowdown_minutes = 2
  @slowdown_people = Array.new

  # calculate slowdown
  calculate_slowdown #store in @slowdown_people

  # number of questions answered including the special answers
  @number_of_answered_questions = @@record.count.to_f/@@names.count.to_f


  @@names.each do |name|
    @@record.select{||}
  end
  
  erb :admin
end

post '/scores' do
  erb :scores
end

def collect_contributors name
  contributors = Array.new
  @@record.each do |row|
    answer = row[2]
    contributors << row[0] if answer == name    
  end
  return contributors.uniq
end

get '/score' do
  name = params[:name]
  name_index = @@names.index(name)
  
  @p_score = Array.new
  @@score[name_index].each_with_index do |number, index| 
    @p_score << [index, number]
  end
  @p_score.sort!{ |a, b|
    b[1] <=> a[1]
  }

  @contributors = collect_contributors(name)
  @name = name

  erb :score
end

get '/record' do
  erb :record
end

get '/admin/share' do
  erb :share_record
end

get '/css/*.*' do |path, ext|
  send_file 'css/' + path + '.' + ext
end


get '/fonts/*.*' do |path, ext|
  send_file 'fonts/' + path + '.' + ext
end

get '/js/*.*' do |path, ext|
  send_file 'js/' + path + '.' + ext
end

get '/img/*.*' do |path, ext|
  send_file 'img/' + path + '.' + ext
end



# post '/who_to_share' do
#   erb :who_to_share
# end


# post '/share' do
#   options = [session[:option0], session[:option1]]
#   question = session[:question]
#   @current_tester = session[:tester]
#   receiver = params[:name]

#   uuid = UUIDTools::UUID.random_create.to_s
#   @@sharing_queue[uuid] = {question: question, 
#                             options: options, 
#                      time_of_asking: Time.now, 
#                               asker: @current_tester, 
#                       asker_thought: params[:thought],
#                            receiver: receiver,
#                   answered_by_asker: false}

#   link = URL + "/answer_share?uuid=" + uuid
#   message = "Hey! %s is asking you %s Click to answer! %s" % [@current_tester, question, link]
#   @@client.account.messages.create(
#     :from => '+17183955452',
#     :to => @@phone_number[receiver],
#     :body => message
#   )

#   puts link
#   redirect to('/start'), 307
# end

# get "/answer_share" do
#   uuid = params[:uuid]
#   sharing = @@sharing_queue[uuid]
  
#   @asker = sharing[:asker]
#   @question = sharing[:question]
#   @options = sharing[:options]
#   @asker_thought = sharing[:asker_thought]

#   @current_tester = sharing[:receiver]

#   session[:uuid] = uuid
#   session[:tester] = @current_tester
#   erb :answer_share
# end

# post "/why" do
#   record_index = params[:index].to_i 
#   record = @@record[record_index]
#   receiver = record[0] 
#   if receiver == session[:tester]
#     session[:reason_index] = record_index
#     redirect to('/edit_reason'), 307
#   end
#   if @@people_asks[session[:tester]] == nil
#       index_array = Array.new
#       index_array << params[:index]
#       @@people_asks[session[:tester]] = index_array
#   else
#       index_array = @@people_asks[session[:tester]]
#       index_array << params[:index]
#   end

#   if @@record_asks[record_index] == nil
#       @@record_asks[record_index] = 1;
#   else
#       @@record_asks[record_index] = @@record_asks[record_index]+1;
#   end
  
#   @current_tester = session[:tester]
#   if record[2] == record[3]
#        not_chosen = record[4]
#   else
#        not_chosen = record[3]
#   end

#   uuid = UUIDTools::UUID.random_create.to_s
#   @@asking_queue[uuid] = {recordID: params[:index],
#                           question: record[1],
#                             chosen: record[2],
#                             not_chosen: not_chosen,
#                      time_of_asking: Time.now,
#                               asker: @current_tester,
#                            receiver: receiver,
#                   answered_by_asker: false}

#   link = URL + "/answer_ask?uuid=" + uuid
  
#   begin 
#      message = "Hey! %s is asking you why you chose %s in the question %s Click to answer! %s" % [@current_tester, record[2], record[1], link]
#      @@client.account.messages.create(
#        :from => '+17183955452',
#        :to => @@phone_number[receiver],
#        :body => message
#      )
#   rescue
#   end

#   redirect to('/lobby'), 307
# end

# post "/edit_reason" do
#   erb :edit_reason
# end

# post "/edit_comment" do
#   session[:comment_index] = params[:index].to_i
#   erb :edit_comment
# end

# post "/done_reason" do
#   index = session[:reason_index]
#   session[:reason_index] = nil
#   if @@record_comments[index] == nil
#       comment_array = Array.new
#       comment_array << params[:thought]
#       @@record_comments[index] = comment_array
#   else
#       comment_array = @@record_comments[index]
#       comment_array << params[:thought]
#   end
#   redirect to('/lobby'), 307
# end

# post "/done_comment" do
#   index = session[:comment_index]
#   session[:comment_index] = nil
#   if @@others_comments[index] == nil
#       comment = Array.new
#       comment[0] = session[:tester]
#       comment[1] = params[:thought]
#       comments_array = Array.new
#       comments_array << comment
#       @@others_comments[index] = comments_array
#   else
#       comment = Array.new
#       comment[0] = session[:tester]
#       comment[1] = params[:thought]
#       comments_array = @@others_comments[index]
#       comments_array << comment
#   end
#   redirect to('/lobby'), 307
# end

# get "/answer_ask" do
#   uuid = params[:uuid]
#   session[:uuid] = uuid
#   asking = @@asking_queue[uuid]

#   @asker = asking[:asker]
#   @question = asking[:question]
#   @chosen = asking[:chosen]
#   @not_chosen = asking[:not_chosen]

#   @current_tester = asking[:receiver]

#   session[:uuid] = uuid
#   session[:tester] = @current_tester
#   erb :answer_ask
# end

# post "/reply_ask" do
#   uuid = session[:uuid]
#   session[:uuid] = nil

#   @@asking_queue[uuid][:receiver_thought] = params[:thought]
#   @@asking_queue[uuid][:time_of_replying] = Time.now

#   record_index = @@asking_queue[uuid][:recordID].to_i
#   if @@record_comments[record_index] == nil
#       comment_array = Array.new
#       comment_array << params[:thought]
#       @@record_comments[record_index] = comment_array
#   else
#       comment_array = @@record_comments[record_index]
#       comment_array << params[:thought]
#   end

#   redirect to('/lobby'), 307
# end

# post "/reply_share" do
#   name = params[:name]
#   uuid = session[:uuid]
#   session[:uuid] = nil

#   @@sharing_queue[uuid][:answer] = name
#   @@sharing_queue[uuid][:receiver_thought] = params[:thought]
#   @@sharing_queue[uuid][:time_of_replying] = Time.now


#   uri = Addressable::URI.parse(URL + "/sharing_history")
#   uri.query_values = {
#     'tester'  => @@sharing_queue[uuid][:asker]
#   }

#   puts uri.to_s
#   # link = URL + "/sharing_history?tester=" + 
#   message = "%s replied your question! Go to Check sharing! to see it! %s" % [@@sharing_queue[uuid][:receiver], uri.to_s]

#   @@client.account.messages.create(
#     :from => '+17183955452',
#     :to => @@phone_number[@@sharing_queue[uuid][:asker]],
#     :body => message
#   )

#   redirect to('/start'), 307
# end

# get "/sharing_history" do 
#   session[:tester] = params[:tester] if params[:tester]
    
#   tmp = @@sharing_queue.select do |uuid, share| 
#     (share[:asker] == session[:tester])
#   end

#   if tmp
#     @sharings = tmp.values
#   else
#     @sharings = Array.new
#   end

#   erb :sharing_history
# end


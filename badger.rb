# Badger
### 
PORT = 7009
### DO NOT CHANGE ANYTHING ABOVE THIS LINE

require "addressable/uri"
require 'sinatra'
require "sinatra/multi_route"
require 'json'
require 'csv'
require 'uuidtools'
require 'time'

require './librarian.rb'
require './player.rb'

IP = "0.0.0.0"

set :bind, '0.0.0.0'
set :port, PORT

enable :sessions

INITIAL_BLOOD = 5
PLAY_ADD_BLOOD  = 1
GUESS_ADD_BLOOD = 1
GUESS_SUBSTRACT_BLOOD = 3


def import_questions
  
  @@categories = Hash.new
  @@questions = Array.new
  
  CSV.foreach("questions.csv") do |row|
    # question, value, categ, dim, att
    @@questions << row[0]
    @@categories[row[0]] = {"value"=>row[1].to_i, "categ"=>row[2], "dim"=>row[3], "att"=>row[4]}
  end

  @@questions.shuffle!
end

# run after import_questions
def extract_categ
  categories = @@categories.values.map{|hash| hash["categ"]}.uniq
  categories.each do |categ|
    next if categ == "F"
    CATEGORIES[categ] = Array.new
    dims = @@categories.values.select{|hash| hash["categ"] == categ}.map{|hash| hash["dim"]}.uniq
    dims.each do |dim|
        CATEGORIES[categ] << dim
    end                              
  end
end

def import_names
  @@names = Array.new
  CSV.foreach("names.csv") do |row|
    @@names << row[0]
  end
end

def declare_variables

  @@data_to_w_r = ["categories", "score_buffer","logged_in","view_report","unlock_someone", 
                   "play_others","play_answer","view_rankings","use_gems","wins", "losses", 
                   "level", "progress", "gems", "unlocked_uuid_index", "coins", "record", 
                   "unlocked"]
  
  @@logged_in = Hash.new
  
  @@players = Hash.new

  @@librarian = Librarian.new(@@names)
  @@librarian.import_historical_bundles "bundles.txt"
end


def initilize_variables
  @@names.each do |name|
    @@logged_in[name] = Array.new
    @@players[name] = Player.new(name, INITIAL_BLOOD, @@questions.count)
  end
end


configure do
  puts "Configuring..."
  URL = "http://%s:%s" % [IP, PORT.to_s]

  import_questions
  import_names
  declare_variables
  initilize_variables

  CATEGORIES = Hash.new
  extract_categ
end


def clear_session
    session.clear
end


def add_new_player
  @@names.each do |name|

    @@logged_in[name] = Array.new    if @@logged_in[name] == nil
    @@players[name] = Play.new(name) if @@players[name] == nil

    @@librarian.add_player name
  end
end

get '/' do
  clear_session
  # @number_of_games_played = 1
  # erb :game_over
  erb :login
end

route :get, :post, '/home' do

  if params["name"]
    puts "name: " + params["name"]
    @@names << params["name"] unless @@names.include? params["name"]
    
    add_new_player

    session[:tester] = params["name"]
  else
    if session[:tester]
      name = session[:tester]
      clear_session
      session[:tester] = name
    else
      puts "Error!"
      clear_session
    end
  end
  
  @@logged_in[session[:tester]] << Time.now
  
  erb :start_play
end

post '/play' do
  @player = @@players[session[:tester]]
  is_game_over = false
  if params["correctness"]

    # {quiz_uuid:xx, guesser:xx, correctness:xx}
    guess_uuid = @@librarian.record_guess({"quiz_uuid" => session[:quiz_uuid],
                                           "guesser" => @player.name,
                                           "correctness" => params["correctness"]
                                          })
    @@librarian.add_to_bundle(session[:bundle_uuid], [session[:quiz_uuid], guess_uuid])

    if params["correctness"] == "true"
      @player.blood += GUESS_ADD_BLOOD
    else
      # GAME OVER
      if @player.blood <= GUESS_SUBSTRACT_BLOOD
        @player.blood = INITIAL_BLOOD

        @number_of_games_played = @@librarian.get_number_of_games_played(session[:bundle_uuid])
        
        is_game_over = true
        
      else
        @player.blood -= GUESS_SUBSTRACT_BLOOD
      end
    end
    
  else
    
    session[:bundle_uuid] = @@librarian.create_new_bundle
  end

  next_index = @player.next_question_index
  @question = @@questions[next_index]
  @options = (@@names - [@player.name]).sample(2)  

  session[:question] = @question
  session[:options] = @options

  if is_game_over
    erb :game_over
  else
    erb :play
  end
end

post '/guess' do
  @player = @@players[session[:tester]]
  @player.blood += PLAY_ADD_BLOOD

  session[:quiz_uuid] = @@librarian.record_quiz({"answer" => params["answer"], 
                                                 "question" => session[:question], 
                                                 "option0" => session[:options][0],
                                                 "option1" => session[:options][1],
                                                 "time" => Time.now, 
                                                 "player" => session[:tester]})
  
  @quiz = @@librarian.get_a_quiz(session[:tester], session[:bundle_uuid])
  erb :guess
end

get '/img/*.*' do |path, ext|
  send_file 'img/' + path + '.' + ext
end



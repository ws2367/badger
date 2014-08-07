# quiz = uuid => {qustion:xx, option0:xx, option1:xx, answer:xx, time:xx, player:xx}
  # 
  # guess = uuid => {quiz_uuid:xx, guesser:xx, answer:xx, correctness:xx}
  # 
  # parcel = [quiz_uuid, guess_uuid]
  # 
  # bundle = uuid => [[guiz_uuid, guess_uuid], [guiz_uuid, guess_uuid], [guiz_uuid, guess_uuid]...]
  # 
  

class Librarian

  def initialize all_names
    @data_to_record = []

    @quizzes = Hash.new
    @guesses = Hash.new
    @bundles = Hash.new
    
    all_names.each do |name|
      initialize_for_a_player name
    end
  end  

  # parcel = [uuid, [{qustion:xx, option0:xx, option1:xx, answer:xx, time:xx}, 
                  #  {qustion:xx, option0:xx, option1:xx, answer:xx, time:xx},
                  #  {qustion:xx, option0:xx, option1:xx, answer:xx, time:xx}],
  #           categ
  #          ]
  def import_historical_bundles file_path
    bundles = nil
    File.open("bundles.txt", 'r') do |file|
      temp = file.read
      bundles = JSON.parse(temp)
    end    

    bundles.each do |name, parcels|
      parcels.each do |parcel|
        parcel[1].each do |quiz|
          uuid = UUIDTools::UUID.random_create.to_s
          quiz["player"] = name
          @quizzes[uuid] = quiz
        end
      end
    end
  end

  def record_all_data
    @data_to_record.each do |name| 
      File.open("record/librarian/" + name + ".txt", 'w') do |file|
        file.write(eval("@" + name).to_json)
      end
    end
  end

  def read_all_data
    @data_to_record.each do |name|
      File.open("record/librarian/" + name + ".txt", 'r') do |file|
        temp = file.read
        code = "@" + name + "=" + "JSON.parse(temp)"
        eval(code)
      end
    end
  end

  def initialize_for_a_player name
    
  end

  def add_player name
    initialize_for_a_player name
  end

  # input = {qustion:xx, option0:xx, option1:xx, answer:xx, time:xx, player:xx}
  def record_quiz quiz
    uuid = UUIDTools::UUID.random_create.to_s
    @quizzes[uuid] = quiz
    return uuid
  end

  def create_new_bundle
    uuid = UUIDTools::UUID.random_create.to_s
    @bundles[uuid] = Array.new
    return uuid
  end

  def add_to_bundle uuid, parcel
    @bundles[uuid] << parcel
  end

  def get_number_of_games_played uuid
    return @bundles[uuid].count 
  end

  def get_a_quiz player, bundle_uuid
    
    quiz_uuids = @bundles[bundle_uuid].map{|parcel| parcel[0]}
    # return @quizzes.select{|uuid, quiz| quiz["player"] != player}.values.sample
    return @quizzes.select{|uuid, quiz| 
      !(quiz_uuids.include? uuid)
      }.values.sample
  end

  # input = {quiz_uuid:xx, guesser:xx, answer:xx, correctness:xx}
  def record_guess guess
    if @quizzes[guess["quiz_uuid"]]["option0"] == @quizzes[guess["quiz_uuid"]]["answer"]
      chosen   = @quizzes[guess["quiz_uuid"]]["option0"]
      unchosen = @quizzes[guess["quiz_uuid"]]["option1"]
    else
      chosen   = @quizzes[guess["quiz_uuid"]]["option1"]
      unchosen = @quizzes[guess["quiz_uuid"]]["option0"]
    end
    
    guess["answer"] = (guess["correctness"] == "true") ? chosen : unchosen

    uuid = UUIDTools::UUID.random_create.to_s
    @guesses[uuid] = guess
    return uuid
  end
end
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

class Librarian

  def initialize all_names
    @notifications = Hash.new
    @records = Hash.new
    @bundles = Hash.new
    @bundles_played = Hash.new
    @unlocked_guesser_uuid = Hash.new
    all_names.each do |name|
      initialize_for_a_player name
    end
  end  

  def initialize_for_a_player name
    @notifications[name] = Array.new if @notifications[name] == nil
    @records[name] = Array.new if @records[name] == nil
    @bundles[name] = Array.new if @bundles[name] == nil
    @bundles_played[name] = Array.new if @bundles_played[name] == nil
  end

  def add_player name
    initialize_for_a_player name
  end

  # win_record = ["true", "true", "false"]
  def record_win(guesser, bundle, author, win_record)
    
    new_bundle = Array.new(bundle)
    new_bundle.each_with_index do |quiz, index|
      quiz["uuid"]   = UUIDTools::UUID.random_create.to_s
      quiz["record"] = win_record[index]      
    end

    @records[author] << {guesser: guesser, bundle:new_bundle}
  end

  # return notification for tester
  def get_notification tester
    ret = Array.new(@notifications[tester])
    @notifications[tester] = Array.new
    return ret
  end

  def record_notification(tester, question, bet, correctness)
    @notifications[tester] << [question, bet, correctness]
  end

  def unlock_guesser(tester, uuid)
    @unlocked_guesser_uuid[tester] = Array.new if @unlocked_guesser_uuid[tester] == nil
    @unlocked_guesser_uuid[tester] << uuid
  end

  def is_guesser_unlocked?(tester, uuid)
    @unlocked_guesser_uuid[tester] = Array.new if @unlocked_guesser_uuid[tester] == nil
    return @unlocked_guesser_uuid[tester].include? uuid
  end

  def get_guesser_questions(tester_name)
    guesser_questions = Array.new
    @records[tester_name].each do |hash|
      hash[:bundle].each do |quiz|
        if quiz["record"] == "true"
          guesser_questions << {"guesser"=> hash[:guesser], 
                                "quiz"=> quiz
                                }
        end
      end
    end
    
    return guesser_questions
  end

  # return an array of records
  def wins_with_author author
    return @records[author]
  end

  def just_played name, uuid
    @bundles_played[name] << uuid
  end

  def has_played? name, uuid
    return false if @bundles_played[name] == nil
    return @bundles_played[name].include?(uuid)
  end

  # return uuid of the parcel
  def create_parcel(name, bundle)
    uuid = UUIDTools::UUID.random_create.to_s
    @bundles[name] = Array.new if @bundles[name] == nil
    @bundles[name] << [uuid, bundle]
    return uuid
  end

  def get_parcels name
    return @bundles[name]
  end

  # return questions about him/her
  # return_value = [
  #                  [bundle_uuid, index, tester_name, quiz]
  #                ]
  def get_questions_of(tester_name)
    my_questions = Array.new
    
    @bundles.each do |name, parcels|
      next if name == tester_name
      next if parcels == nil
    
      parcels.each do |parcel|
        bundle = parcel[1]
    
        if bundle[0]["option0"] == tester_name or 
           bundle[0]["option1"] == tester_name
          bundle.each_with_index do |quiz, index|
            my_array = [parcel[0], index, name, quiz]
            my_questions << my_array
          end
        end
      end
    end
    return my_questions
  end

  # return the name and the matched bundle
  def get_bundle_by_uuid uuid
    @bundles.each do |name, parcels|
      parcels.each do |parcel|
        return [name, parcel[1]] if parcel[0] == uuid
      end
    end
  end

  def get_relevant_quizzes name
    return @bundles.values.flatten(1).map{ |parcel| parcel[1]}.flatten.
               select{|quiz| (quiz["option0"] == name) or (quiz["option1"] == name)}
  end
end
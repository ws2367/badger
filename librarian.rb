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
    @records = Hash.new
    @bundles = Hash.new
    @bundles_played = Hash.new
    all_names.each do |name|
      initialize_for_a_player name
    end
    puts "bundle whole first"
    puts @bundles.inspect
  end  

  def initialize_for_a_player name
    @records[name] = Array.new if @records[name] == nil
    @bundles[name] = Array.new if @bundles[name] == nil
    @bundles_played[name] = Array.new if @bundles_played[name] == nil
  end

  def add_player name
    initialize_for_a_player name
  end

  # win_record = ["true", "true", "false"]
  def record_win(guesser, uuid, win_record)
    author, bundle = get_bundle_by_uuid(uuid)
    @records[author] << {guesser: guesser, win_record: win_record, bundle:bundle}
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
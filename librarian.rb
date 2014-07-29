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
    @bundles = Hash.new
    @bundles_played = Hash.new
    all_names.each do |name|
      initialize_for_a_player name
    end
  end  

  def initialize_for_a_player name
    @bundles[name] = Array.new if @bundles[name] == nil
    @bundles_played[name] = Array.new if @bundles_played == nil
  end

  def add_player name
    initialize_for_a_player name
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
  def get_questions_of(tester_name, all_names)
    my_questions = Array.new
    all_names.each do |name|
      next if name == tester_name
      bundle_array = @bundles[name]
      next if bundle_array == nil
      bundle_array.each do |bundle|
        quiz_array = bundle[1]
        if quiz_array[0]["option0"] == tester_name or 
           quiz_array[0]["option1"] == tester_name
          quiz_array.each_with_index do |quiz, index|
            my_array = [bundle[0], index, name, quiz]
            my_questions << my_array
          end
        end
      end
    end
    return my_questions
  end

  # return the name and the matched bundle
  def get_bundle_by_uuid(uuid, all_names)
    all_names.each do |name|
      next if @bundles[name] == nil
      @bundles[name].each do |parcel|
        return [name, parcel[1]] if parcel[0] == uuid
      end
    end
  end

  def get_relevant_quizzes name
    return @bundles.values.flatten(1).map{ |parcel| parcel[1]}.flatten.
               select{|quiz| (quiz["option0"] == name) or (quiz["option1"] == name)}
  end
end
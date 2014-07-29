

class Marker
  
  def initialize categorizations
    @scores = Hash.new
    categories = categorizations.values.map{|hash| hash["categ"]}.uniq
    categories.each do |categ|
      dims = categorizations.values.select{|hash| hash["categ"] == categ}.map{|hash| hash["dim"]}.uniq
      dims.each do |dim|
        attributes = categorizations.values.select{|hash| hash["categ"] == categ and hash["dim"] == dim}.
                                     map{|hash| hash["attribute"]}.uniq
        attributes.each do |att|
          @scores[categ] = Hash.new
          @scores[categ][dim] = Hash.new
          @scores[categ][dim][att] = 0.0
        end                              
      end
    end
  end

  def categ categ
    return @scores[category].values.inject(0){|sum, dim| sum + dim.values.reduce(:+)}
  end

  def dim(categ, dim)
    return @scores[category][dim].values.reduce(:+)
  end

  def mod_score(categ, dim, attribute, value)
    return @scores[category][dim][attribute] += value
  end

  @scores[category] += value
    elsif quiz["answer"] == another_option
      @scores[category] -= value
end
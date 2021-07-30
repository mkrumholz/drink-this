require 'pycall/import'
include PyCall::Import

pyimport :pandas
pyimport :numpy
pyfrom :sklearn, import: :metrics
pyfrom 'sklearn.metrics', import: :pairwise
pyfrom 'sklearn.metrics.pairwise', import: :euclidean_distances

class RecommendationService
  # Should take a user_id or user as a parameter (who's making the request)
  def self.recommendation
    sklearn = PyCall.import_module("sklearn")

    # Make the data into a DataFrame, set the name as an index, and make nil values into 0s
    csv_data = Pandas.read_csv("./db/data/cocktail_ratings.csv") #replace with our ratings data
    df = csv_data.set_index('name').fillna(0) #will be user_id instead of name

    # Get the euclidean distances between the vector and itself, pairwise
    euclidean = Numpy.round(sklearn.metrics.pairwise.euclidean_distances(df,df),2)
    # alternate option for measuring similarity
    # euclidean = Numpy.round(sklearn.metrics.pairwise.cosine_similarity(df,df),2)

    # making the array of euclidean distances into a new DataFrame (pairwise, so the columns and rows are both users)
    similar = Pandas.DataFrame.new(data=euclidean, index=df.index,columns=df.index)
    
    # get the similarities for the user requesting the recommendation (and make it into a DataFrame)
    # sort true with Euclidean Distance, false with cosine similarity
    max = similar.loc['Max'].sort_values(0,ascending=true)[1..5] #here, Max is replacing our USER_ID for the user requesting the rec
    # max = similar.loc['Max'].sort_values(0,ascending=false)[1..5] #here, Max is replacing our USER_ID for the user requesting the rec
    df_max = Pandas.DataFrame.new(data=max, index=df.index)

    # prepping the cocktail data to merge with the user similarity data
    pivoted = Pandas.melt(df.reset_index(),id_vars='name',value_vars=df.keys)

    # scraping out 0 (nil) ratings and merging similarity data with cocktail data
    scraped_pivot = pivoted[pivoted.value != 0]
    total = df_max.reset_index().merge(scraped_pivot).dropna()

    # creating a comparison metric (weighted rating) based on euclidean distance (ed_adjusted * rating)
    total['weightedRating']=(1 / total['Max']+1)*total['value']
    # total['weightedRating']=total['Max']*total['value'] # Use this one for cosine similarity

    # Adding up the similarities by drink and aggregating the data
    similarity_weighted = total.groupby('variable').sum()[['Max','weightedRating']]
    
    # Removing drinks user has already rated
    max_pivot = pivoted[pivoted.name == 'Max'] # won't be 'Max', will be user_id (current_user.id?)
    reset_sw = similarity_weighted.reset_index()
    unknown_to_user = reset_sw.merge(max_pivot).set_index('variable')
    unknown_to_user = unknown_to_user[unknown_to_user.value == 0]

    # Finishing created the weighted avg adjusted euclid distance
    empty = Pandas.DataFrame.new()
    empty['weightedAvgRecScore'] = unknown_to_user['Max']/unknown_to_user['weightedRating']

    # Make the final (best) recommendation
    recommendation = empty[empty.weightedAvgRecScore == empty.weightedAvgRecScore.max()]
    # empty.loc[empty['weightedAvgRecScore'].idxmax()]

    # need to format for incoming data with user_ids, etc. 
  end
end

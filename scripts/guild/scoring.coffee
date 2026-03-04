###
Utility scoring module for Four Forces
###

exports.scoreSegment = (text, onto) ->
  result = {}
  for axis, data of onto.forces
    poles = data.poles
    pos  = poles[0]?.positive or "positive"
    neu  = poles[0]?.neutral  or "neutral"
    neg  = poles[0]?.negative or "negative"
    val  = Math.random() * 2 - 1
    keyword = if val > 0.4 then pos else if val < -0.4 then neg else neu
    result[axis] =
      score: val
      keyword: keyword
  return result

exports.aggregateScores = (segScores) ->
  axes = Object.keys(segScores[0])
  result = {}
  for axis in axes
    vals = segScores.map (s) -> s[axis].score
    sum = 0
    for v in vals then sum += v
    avg = sum / vals.length
    result[axis] =
      score: avg
      keyword: segScores[0][axis].keyword
  return result

exports.computeMetrics = (timeline) ->
  if timeline.length < 2 then return {}
  first = timeline[0]
  last  = timeline[timeline.length - 1]
  delta = {}
  for axis of first when last[axis]?
    delta[axis] = last[axis].score - first[axis].score
  return { delta: delta }

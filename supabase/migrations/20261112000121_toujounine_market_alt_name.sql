-- Reported: searching "سوق توجونين" (the common spelling, with a long و)
-- on the operator dispatch screen doesn't resolve to this app's own
-- verified "سوق توجنين" place (Marché de Toujounine, 18.1380, -15.9250) -
-- instead the admin ends up picking a Google Places result for a
-- similarly-named but differently-located market elsewhere in Nouakchott
-- (DestinationSearchRepository always lists this app's own places *before*
-- any Google result, but only once the local search actually matches the
-- query text - see 20261007000111, which added alt_names for exactly this
-- "teach it a spelling variant" case).
update public.places
set alt_names = array_append(alt_names, 'سوق توجونين')
where name_ar = 'سوق توجنين'
  and not ('سوق توجونين' = any(alt_names));

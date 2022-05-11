### v1.0.0
###
### Usage:
### (any of the values can be omitted, in which case the defaults will be used instead)
### ('Kenko' and 'Kogeki' in this example are the names of the trainers we are going to add)
###
### $lcmal_trainers={} if !defined?(lcmal_trainers)
### $lcmal_trainers['Kenko'] = {
###   :party => [
###     {
###       TPSPECIES => 31,
###       TPLEVEL => 1,
###       TPFORM => 0,
###       TPITEM => 0,
###       TPMOVE1 => 419,
###       TPMOVE2 => 0,
###       TPMOVE3 => 0,
###       TPMOVE4 => 0,
###       TPABILITY => 0,
###       TPGENDER => 0, # 0 Male, 1 Female, 2 Other
###       TPSHINY => false,
###       TPNATURE => 0,
###       TPIV => 10,
###       TPHPEV => 0,
###       TPATKEV => 0,
###       TPDEFEV => 0,
###       TPSPEEV => 0,
###       TPSPAEV => 0,
###       TPSPDEV => 0,
###       TPHAPPINESS => 70,
###       TPNAME => '',
###       TPSHADOW => false,
###       TPBALL => 0
###     },
###     {
###       TPSPECIES => 36,
###       TPMOVE1 => 364
###     }
###   ]
### }
### $lcmal_trainers['Kogeki'] = {
###   :party => [
###     {
###       TPSPECIES => 34,
###       TPMOVE1 => 364
###     }
###   ],
###   :items => [
###     # cfr pbGetSortOrderByType in PokemonBag.rb for a list of most item ids
###     228, # Full heal
###     232, # Revive
###     # This works too if you prefer
###     PBItems::MAXPOTION,
###     PBItems::BUBBLETEA
###   ]
### }
###
####################################################################

if !defined?(lcmal_oldPbLoadTrainer)
  alias :lcmal_oldPbLoadTrainer :pbLoadTrainer
end

def pbLoadTrainer(trainerid, trainername, partyid=0)
  trainerdata=lcmal_getModTrainerData(trainerid, trainername, partyid)
  if trainerdata
    $cache.trainers[trainerid]={} if !$cache.trainers[trainerid]
    $cache.trainers[trainerid][trainername]={} if !$cache.trainers[trainerid][trainername]
    $cache.trainers[trainerid][trainername][partyid]=trainerdata
  end
  return lcmal_oldPbLoadTrainer(trainerid, trainername, partyid)
end

def lcmal_getModTrainerData(trainerid, trainername, partyid=0)
  trainerarray=$cache.trainers[trainerid]
  trainer=trainerarray.dig(trainername,partyid)
  return nil if trainer
  return nil if !defined?($lcmal_trainers)
  return [
    lcmal_getTrainerTeam($lcmal_trainers[trainername][:party]), # Mons
    lcmal_getTrainerItems($lcmal_trainers[trainername][:items]) # Items
  ]
end

def lcmal_getTrainerTeam(data)
  retval=[]
  for mon in data
    item=[]
    for val in TPDEFAULTS
      item.push(val)
    end
    for key, val in mon
      item[key]=val
    end
    retval.push(item)
  end
  return retval
end

def lcmal_getTrainerItems(data)
  return [] if !data
  return data
end

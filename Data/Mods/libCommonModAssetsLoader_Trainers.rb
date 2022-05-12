### v1.0.0
###
### Usage:
### (any of the values can be omitted, in which case the defaults will be used instead)
### ('Kenko' and 'Kogeki' in this example are the names of the trainers we are going to add)
###
### Call a battle with a custom backdrop from an event:
### lcmal_pbTrainerBattle(PBTrainers::WANDERER, 'Kenko', 'gg wp!', false, 0, false, 0, backdrop: 'Starlight')
###
### Code to be put in your mod:
### $lcmal_trainerClasses={} if !defined?(lcmal_trainerClasses)
### $lcmal_trainerClasses['WANDERER']={
###   :title => "Omniversal Wanderer",
###   :skill => 100,
###   :moneymult => 17,
###   :battleBGM => "Magical Girl's Crusade.ogg",
###   :winBGM => "Victory2",
###   :sprites => {
###     :fullFigure => 'Data/Mods/libCommonModAssets/trainer400.png',
###     :overworld => 'Data/Mods/libCommonModAssets/trchar400.png',
###     :vsBar => 'Data/Mods/libCommonModAssets/vsBar400.png',
###     :vsTrainer => 'Data/Mods/libCommonModAssets/vsTrainer400.png'
###   }
### }
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

###################################################
# Classes

def PBTrainers.const_missing(name)
  newVal=lcmal_ensureTrainerClass(name)
  return newVal
end

def lcmal_ensureTrainerClass(name)
  return nil if !defined?($lcmal_trainerClasses)
  classData=$lcmal_trainerClasses[name.to_s]
  return nil if !classData
  newVal=PBTrainers.getCount()
  # Update the sprites
  lcmal_updateTrainerClassSprites(newVal, classData[:sprites])
  # Update the data
  lcmal_updateTrainerClassData(name, newVal, classData)
  # Fin
  return newVal
end

def lcmal_updateTrainerClassSprites(newVal, spritesData)
  lcmal_replace_file(spritesData[:vsBar], sprintf('Graphics/Transitions/vsBar%d',newVal))
  lcmal_replace_file(spritesData[:vsTrainer], sprintf('Graphics/Transitions/vsTrainer%d',newVal))
  lcmal_replace_file(spritesData[:fullFigure], sprintf('Graphics/Characters/trainer%d',newVal))
  lcmal_replace_file(spritesData[:overworld], sprintf('Graphics/Characters/trchar%d',newVal))
end

def lcmal_replace_file(src, dest)
  return nil if !src
  $lcmal_fileMapping={} if !defined?($lcmal_fileMapping)
  $lcmal_fileMapping[dest]=src
  # File.open("#{dest}.png", 'w') { |f| f.write(File.read(src)) }
end

if !defined?(lcmal_oldPbResolveBitmap)
  alias :lcmal_oldPbResolveBitmap :pbResolveBitmap
end
def pbResolveBitmap(x, *args, **kwargs)
  $lcmal_fileMapping={} if !defined?($lcmal_fileMapping)
  actual=$lcmal_fileMapping[x]
  if actual
    return self.lcmal_oldPbResolveBitmap(actual, *args, **kwargs)
  end
  return self.lcmal_oldPbResolveBitmap(x, *args, **kwargs)
end

module RPG
  module Cache
    if !defined?(self.lcmal_oldLoad_bitmap)
      class <<self
        alias_method :lcmal_oldLoad_bitmap, :load_bitmap
      end
    end
    def self.load_bitmap(filename, *args, **kwargs)
      $lcmal_fileMapping={} if !defined?($lcmal_fileMapping)
      actual=$lcmal_fileMapping[filename]
      if actual
        return self.lcmal_oldLoad_bitmap(actual, *args, **kwargs)
      end
      return self.lcmal_oldLoad_bitmap(filename, *args, **kwargs)
    end
  end
end

def lcmal_updateTrainerClassData(name, newVal, classData)
  # Update PBTrainers
  PBTrainers.define_singleton_method(:getCount) do
    return newVal+1
  end
  PBTrainers.define_singleton_method(:maxValue) do
    return newVal
  end
  PBTrainers.const_set(name, newVal)
  $lcmal_PBTrainersMessages={} if !defined?($lcmal_PBTrainersMessages)
  $lcmal_PBTrainersMessages[newVal]=classData[:title] if classData[:title]
  # Update the cache
  $cache.trainers[newVal]={}
  $cache.trainertypes[newVal]=[
    newVal, # ID
    name.to_s, # Name
    classData[:title],
    classData[:moneymult],
    classData[:battleBGM],
    classData[:winBGM],
    nil,
    0,
    classData[:skill]
  ]
  # for i in 0...$cache.trainertypes[18].length
  #   Kernel.pbMessage(_INTL('{1}||{2}', $cache.trainertypes[18][i], $cache.trainertypes[newVal][i]))
  # end
end

class PBTrainers
  def self.getName(id)
    $lcmal_PBTrainersMessages={} if !defined?($lcmal_PBTrainersMessages)
    message=$lcmal_PBTrainersMessages[id]
    return message if message
    return pbGetMessage(MessageTypes::TrainerTypes,id)
  end
end

##################################
# Backdrop

$lcmal_enforcedBackDrop=nil # Reset on reset
def lcmal_pbTrainerBattle(*args, backdrop: nil, **kwargs)
  $lcmal_enforcedBackDrop=backdrop
  result=pbTrainerBattle(*args, **kwargs)
  $lcmal_enforcedBackDrop=nil
  return result
end

if !defined?(lcmal_oldPbGetMetadata)
  alias :lcmal_oldPbGetMetadata :pbGetMetadata
end
def pbGetMetadata(mapid, metadataType)
  if metadataType == MetadataBattleBack && defined?($lcmal_enforcedBackDrop) && $lcmal_enforcedBackDrop
    return $lcmal_enforcedBackDrop
  end
  return lcmal_oldPbGetMetadata(mapid, metadataType)
end

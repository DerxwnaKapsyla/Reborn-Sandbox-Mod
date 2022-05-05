#####################################################
#              Reborn specifications                #
#####################################################

# Please note that the Sandbox's Map ID is -5
# This makes it episode-agnostic, but requires one additional step when editing the map
# (it needs to be renamed Map-05 after it has been saved and compiled)

SANDBOX_ACCESS_FROM_ANYWHERE = false
SANDBOX_MAPID = -5
SANDBOX_METADATA_MAPID = 38 # Copy the Grand Hall's metadata for the Sandbox zone
SANDBOX_MAX_SPECIES = 807 # PBSpecies.maxValue

#####################################################
#  Things that need to be checked between episodes  #
#####################################################

#Metadata
if !defined?(sandbox_oldPbGetMetadata)
  alias :sandbox_oldPbGetMetadata :pbGetMetadata
end
def pbGetMetadata(mapid, metadataType)
  return sandbox_oldPbGetMetadata(SANDBOX_METADATA_MAPID, metadataType) if mapid == SANDBOX_MAPID
  return sandbox_oldPbGetMetadata(mapid, metadataType)
end
class Cache_Game
  if !defined?(sandbox_oldMapLoad)
    alias :sandbox_oldMapLoad :map_load
  end
  def map_load(mapid)
    return sandbox_oldMapLoad(mapid) if mapid >= 0
    puts "loading map",mapid
    return load_data(sprintf("Data/Map%03d.rxdata", mapid))
  end
end

# Sandbox access and money
module PokemonPCList
  if !defined?(self.sandbox_oldCallCommand)
    class <<self
      alias_method :sandbox_oldCallCommand, :callCommand
    end
  end
  def self.callCommand(cmd)
    retval=self.sandbox_oldCallCommand(cmd)
    if defined?($sandbox_overridePcLogoff) && $sandbox_overridePcLogoff
      $sandbox_overridePcLogoff=false
      return false
    end
    return retval
  end
end
class Sandbox_ManageAccess
  def getAccessPointData
    mapId=$game_map.map_id
    # Structure: Greeting line, Access X, Access Y
    return [_INTL('Please follow the yellow line.'), 7, 4] if mapId==38 # Grand Hall
    return [_INTL('Initiating warp procedure.'), 52, 44] if mapId==355 # Agate Circus
    return [_INTL('Please follow the yellow line.'), 7, 4] if SANDBOX_ACCESS_FROM_ANYWHERE && mapId!=SANDBOX_MAPID
    return nil
  end
  def shouldShow?
    accessData=getAccessPointData
    return accessData ? true : false
  end
  def name
    return _INTL('Sandbox Mode')
  end
  def access
    $sandbox_overridePcLogoff=true
    accessData=getAccessPointData
    Kernel.pbMessage(accessData[0])
    # Setup map & Transfer player
    # mapSandbox=Game_Map.new
    # mapSandbox.setup(SANDBOX_MAPID)
    mapSandbox=[SANDBOX_MAPID,accessData[1],accessData[2]]
    pbFadeOutIn(99999){
      Kernel.pbCancelVehicles
      # $game_switches[:Starting_Over]=true
      $game_temp.player_new_map_id=mapSandbox[0]
      $game_temp.player_new_x=mapSandbox[1]
      $game_temp.player_new_y=mapSandbox[2]
      $game_temp.player_new_direction=2
      $scene.transfer_player if $scene.is_a?(Scene_Map)
      $game_map.refresh
    }
  end
end
class Sandbox_GiveMoney
  def shouldShow?
    return $game_map.map_id == SANDBOX_MAPID
  end
  def name
    return _INTL('Gimme money plz')
  end
  def access
    params=ChooseNumberParams.new
    params.setRange(0, 999999)
    params.setDefaultValue($Trainer.money)
    $Trainer.money = Kernel.pbMessageChooseNumber(_INTL('How much do you want to end up with? You currently have ${1}', $Trainer.money), params)
  end
end
PokemonPCList.registerPC(Sandbox_ManageAccess.new)
PokemonPCList.registerPC(Sandbox_GiveMoney.new)

# From Sandbox E17; the sandbox actually comments out the option in the PokeGear, but doing this instead should ensure compatibility with SWM
class Scene_Pokegear
  def tryConnect
    #####MODDED, was $scene=Connect.new
	  Kernel.pbMessage("Online play is disabled in the Sandbox Mode mod") #####MODDED
  end
end

# Pls stop using the wrong version on the wrong Reborn Episode :(
swm_target_version='19'
if !getversion().start_with?(swm_target_version)
  Kernel.pbMessage(_INTL('Sorry, but this version of the Sandbox Mode was designed for Pokemon Reborn Episode {1}', swm_target_version))
  Kernel.pbMessage(_INTL('Using it in an episode it was not designed for is no longer allowed.'))
  Kernel.pbMessage(_INTL('It simply causes too many problems.'))
  exit
end

# Trainer battles
if !defined?(sandbox_oldPbLoadTrainer)
  alias :sandbox_oldPbLoadTrainer :pbLoadTrainer
end
def pbLoadTrainer(trainerid, trainername, partyid=0)
  Sandbox_addTrainerData(trainerid, trainername, partyid)
  return sandbox_oldPbLoadTrainer(trainerid, trainername, partyid)
end

def Sandbox_addTrainerData(trainerid, trainername, partyid)
  trainerarray=$cache.trainers[trainerid]
  trainer=trainerarray.dig(trainername,partyid)
  return nil if trainer
  # Missing; add it
  species,move=Sandbox_getTrainerData(trainername)
  return nil if !species
  $cache.trainers[trainerid][trainername]={} if !$cache.trainers[trainerid][trainername]
  $cache.trainers[trainerid][trainername][partyid]=[
    Sandbox_getTrainerTeam(species, move), # Mons
    []
  ]
end

def Sandbox_getTrainerTeam(species, move)
  retval=[]
  for i in 0..5
    monData=[]
    monData[TPSPECIES]=species
    monData[TPLEVEL]=1
    monData[TPFORM]=0
    monData[TPITEM]=0
    monData[TPMOVE1]=move
    monData[TPMOVE2]=0
    monData[TPMOVE3]=0
    monData[TPMOVE4]=0
    monData[TPABILITY]=0
    monData[TPGENDER]=0
    monData[TPSHINY]=false
    monData[TPNATURE]=0
    monData[TPIV]=10
    monData[TPHPEV]=0
    monData[TPATKEV]=0
    monData[TPDEFEV]=0
    monData[TPSPEEV]=0
    monData[TPSPAEV]=0
    monData[TPSPDEV]=0
    monData[TPHAPPINESS]=70
    monData[TPNAME]=''
    monData[TPSHADOW]=false
    monData[TPBALL]=0
    retval.push(monData)
  end
  return retval
end

def Sandbox_getTrainerData(trainername)
  # returns [Species, Move]
  case trainername
  when 'Kenko'
    return 31, 419
  when 'Kogeki'
    return 34, 364
  when 'Boei'
    return 62, 383
  when 'Sokudo'
    return 189, 410
  when 'Chusho'
    return 45, 212
  when 'Mori'
    return 186, 556
  end
  return nil, nil
end

#####################################################
#              Other custom scripts                 #
#####################################################

# From Sandbox E17: PokemonDayCare, line 496
def Sandbox_pbHatchAll
  for egg in $Trainer.party
    if egg.egg?
      egg.eggsteps=0
      pbHatch(egg)
    end
  end
end

# From Sandbox E17: PokemonUtilities, line 4
def Sandbox_ChangeNature(pkmn)
  return aChangeNature(pkmn)
	# aNatureChoices = [_INTL("Attack"),_INTL("Defense"),_INTL("Sp.Atk"),_INTL("Sp.Def"),_INTL("Speed"),_INTL("Cancel")]
	# aNatIDs = [0, 1, 3, 4, 2, -1]
	
	# aNatImp = Kernel.pbMessage(_INTL("Improve what?"),aNatureChoices,6)
	# if (aNatImp >= 0) && (aNatImp < 5)
	# 	aNatRed = Kernel.pbMessage(_INTL("Reduce what?"),aNatureChoices,6)
		
	# 	if (aNatRed >= 0) && (aNatRed < 5)
	# 		pkmn.setNature((aNatIDs[aNatImp]*5)+aNatIDs[aNatRed])
	# 	end
	# end
end

# Sandbox movement
def Sandbox_TransferPlayer(iX, iY)
  # If transferring player, showing message, or processing transition
  if $game_temp.player_transferring or
     $game_temp.message_window_showing or
     $game_temp.transition_processing
    # End
    return false
  end
  # Set transferring player flag
  $game_temp.player_transferring = true
  
  # Coordinates
  $game_temp.player_new_map_id = -5
  $game_temp.player_new_x = iX
  $game_temp.player_new_y = iY
  $game_temp.player_new_direction = $game_player.direction
end

# Pokemon creation
def Sandbox_CreatePokemon
  return Kernel.pbMessage(_INTL('Oh, ok.')) if Kernel.pbMessage(_INTL('I have the ability to generate a specific Pokemon for you.\r\nWould you like me to do this?'), [_INTL('Yes'), _INTL('No')], 1) != 0
  species=Sandbox_chooseSpecies()
  return nil if species == nil
  speciesName=PBSpecies.getName(species)
  level=Sandbox_chooseLevel(speciesName)
  pkmn=PokeBattle_Pokemon.new(species, level, $Trainer)
  form=Sandbox_getPkmnForm(species, speciesName)
  pkmn.form=form if form != nil
  pkmn.makeShiny if Kernel.pbMessage(_INTL('Do you want a shiny {1}?', speciesName), [_INTL('Yes'), _INTL('No')], 2) == 0
  Sandbox_setInitialMoves(pkmn)
  pkmn.calcStats
  Kernel.pbAddPokemon(pkmn)
end

def Sandbox_setInitialMoves(pkmn)
  #Moves
  for i in 0..4
    pkmn.pbDeleteMoveAtIndex(0)
  end
  moves=[]
  initialmoves = pkmn.getMoveList
  for k in initialmoves
    if k[0] <= pkmn.level
      moves.push(k[1])
    end
  end
  finalmoves=[]
  finalmovesId=[]
  listend=[moves.length-4, 0].max
  for i in listend..listend+3
    moveid=(i>=moves.length) ? 0 : moves[i]
    moveid=0 if finalmovesId.include?(moveid)
    finalmoves.push(PBMove.new(moveid))
    finalmovesId.push(moveid)
  end 
  for i in 0..3
    pkmn.moves[i]=finalmoves[i]
  end
  pkmn.pbRecordFirstMoves
end

def Sandbox_getPkmnForm(species, speciesName)
  if Sandbox_isAlternateFormsPackInstalled?
    # Alternate forms pack installed: unleash the horde!
    formnames=Sandbox_getFormNames(species)
    return nil if formnames.length <= 1
    formnamesStrings = []
    for name in formnames
      formnamesStrings.push(name[0])
    end
    return formnames[Kernel.pbMessage(_INTL('Which form would you like?'), formnamesStrings, 1)][1]
  end
  # Base game
  alolans=[19, 20, 26, 27, 28, 37, 38, 50, 51, 52, 53, 74, 75, 76, 88, 89, 103, 105]
  return nil if !alolans.include?(species)
  return nil if Kernel.pbMessage(_INTL('Normal or alolan {1}?', speciesName),[_INTL('Normal'), _INTL('Alolan')], 1) != 1
  return 1
end

def Sandbox_isAlternateFormsPackInstalled?
  # Is this the alternate forms pack mod? Ask drapion!
  formnames=Sandbox_getFormNames(getID(PBSpecies, :DRAPION))
  return formnames.length > 1
end

def Sandbox_getFormNames(speciesId)
  formnames=pbGetMessage(MessageTypes::FormNames, speciesId)
  if !formnames || formnames==''
    formnames=['']
  else
    formnames=strsplit(formnames,/,/)
  end
  result=[]
  for i in 0...formnames.length
    name=formnames[i].strip
    next if name == ''
    result.push([name, i])
  end
  return result
end

def Sandbox_chooseLevel(speciesName)
  params=ChooseNumberParams.new
  params.setRange(1, PBExperience::MAXLEVEL)
  params.setDefaultValue(5)
  return Kernel.pbMessageChooseNumber(_INTL('What level do you want your {1} to be at?', speciesName), params)
end

def Sandbox_pbChooseSpeciesOrdered(default)
  cmdwin=pbListWindow([],200)
  commands=[]
  for i in 1..SANDBOX_MAX_SPECIES
    cname=getConstantName(PBSpecies,i) rescue nil
    commands.push([i,PBSpecies.getName(i)]) if cname
  end
  commands.sort! {|a,b| a[1]<=>b[1]}
  realcommands=[]
  for command in commands
    realcommands.push(_ISPRINTF("{1:03d} {2:s}",command[0],command[1]))
  end
  ret=pbCommands2(cmdwin,realcommands,-1,default-1,true)
  cmdwin.dispose
  return ret>=0 ? commands[ret][0] : 0
end

def Sandbox_chooseSpecies
  choice=Kernel.pbMessage(
    _INTL('How would you like to choose its species?'),
    [
      _INTL('Find name'),
      _INTL('Pokédex id'),
      _INTL('Show me a list')
    ],
    1
  )
  if choice == 0
    nameIn=pbEnterPokemonName(_INTL('What to look for?'), 0, 15, '')
    nameInDown=nameIn.downcase
    found=[]
    for i in 1..SANDBOX_MAX_SPECIES
      name=PBSpecies.getName(i)
      tmp=name.downcase
      next if !tmp.include?(nameInDown)
      found.push([i, name])
    end
    if found.length < 1
      Kernel.pbMessage(_INTL("Sorry, couldn't find any {1}.", nameIn))
      return nil
    elsif found.length > 1
      names=[]
      for i in 0...found.length
        names.push(found[i][1])
      end
      i=Kernel.pbMessage(
        _INTL('Found {1} species', found.length),
        names,
        0 # 0 here prevents exiting without making a choice
      )
      return found[i][0]
    else
      return found[0][0]
    end
  elsif choice == 1
    params=ChooseNumberParams.new
    params.setRange(1,SANDBOX_MAX_SPECIES)
    params.setDefaultValue(1)
    newSpecies=Kernel.pbMessageChooseNumber(_INTL('What is its pokédex ID?'), params)
  else
    return Sandbox_pbChooseSpeciesOrdered(1)
  end
end
#####/MODDED

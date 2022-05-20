#####################################################
#              Reborn specifications                #
#####################################################

# Please note that the Sandbox's Map ID is -5
# This makes it episode-agnostic, but requires one additional step when editing the map
# (it needs to be renamed Map-05 after it has been saved and compiled)

SANDBOX_ACCESS_FROM_ANYWHERE = true
SANDBOX_MAPNAME = 'Sandbox Zone'
SANDBOX_MAPID = -5
SANDBOX_METADATA_MAPID = 38 # Copy the Grand Hall's metadata for the Sandbox zone
SANDBOX_MAX_SPECIES = 807 # PBSpecies.maxValue

#####################################################
#  Things that need to be checked between episodes  #
#####################################################

# Metadata
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
  if !defined?(sandbox_oldCacheMapInfos)
    alias :sandbox_oldCacheMapInfos :cacheMapInfos
  end
  def cacheMapInfos(*args, **kwargs)
    result=sandbox_oldCacheMapInfos(*args, **kwargs)
    $cache.mapinfos[SANDBOX_MAPID]=$cache.mapinfos[SANDBOX_METADATA_MAPID].clone
    $cache.mapinfos[SANDBOX_MAPID].name=SANDBOX_MAPNAME
    return result
  end
end
class Game_Map
  if !defined?(sandbox_oldName)
    alias :sandbox_oldName :name
  end
  def name(*args, **kwargs)
    return SANDBOX_MAPNAME if self.map_id == SANDBOX_MAPID
    return sandbox_oldName(*args, **kwargs)
  end
end

# Sandbox access and money
class PokemonMapMetadata
  attr_accessor :sandbox_returnPoint
  def sandbox_saveReturnPoint(returnPoint)
    # Kernel.pbMessage(returnPoint.join(', '))
    @sandbox_returnPoint=returnPoint
  end
  def sandbox_getReturnPoint(item=nil)
    # Kernel.pbMessage(@sandbox_returnPoint.join(', '))
    return @sandbox_returnPoint if !item
    return @sandbox_returnPoint[0] if item == 'mapid'
    raise ArgumentError.new("ERROR:: sandbox_getReturnPoint:: unrecognized item \"#{item}\"")
  end
end
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
    return [_INTL('Initiating warp procedure.'), 7, 4] if SANDBOX_ACCESS_FROM_ANYWHERE && mapId!=SANDBOX_MAPID
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
    $PokemonMap.sandbox_saveReturnPoint([$game_map.map_id,$game_player.x,$game_player.y,$game_player.direction])
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
    params.setRange(0, 9999999)
    params.setDefaultValue($Trainer.money)
    $Trainer.money = Kernel.pbMessageChooseNumber(_INTL('How much do you want to end up with? You currently have ${1}', $Trainer.money), params)
  end
end
class Sandbox_ExitSandbox
  def shouldShow?
    return $game_map.map_id == SANDBOX_MAPID
  end
  def name
    mapid=$PokemonMap.sandbox_getReturnPoint('mapid')
    return _INTL('Return to {1}', pbGetMapNameFromId(mapid))
  end
  def access
    $sandbox_overridePcLogoff=true
    Kernel.pbMessage(_INTL('Initiating warp procedure.'))
    # Setup map & Transfer player
    # mapTarget=Game_Map.new
    # mapTarget.setup($PokemonMap.sandbox_getReturnPoint('mapid'))
    mapTarget=$PokemonMap.sandbox_getReturnPoint()
    pbFadeOutIn(99999){
      Kernel.pbCancelVehicles
      # $game_switches[:Starting_Over]=true
      $game_temp.player_new_map_id=mapTarget[0]
      $game_temp.player_new_x=mapTarget[1]
      $game_temp.player_new_y=mapTarget[2]
      $game_temp.player_new_direction=mapTarget[3]
      $scene.transfer_player if $scene.is_a?(Scene_Map)
      $game_map.refresh
    }
  end
end
PokemonPCList.registerPC(Sandbox_ManageAccess.new)
PokemonPCList.registerPC(Sandbox_GiveMoney.new)
PokemonPCList.registerPC(Sandbox_ExitSandbox.new)

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
$lcmal_trainerClasses={} if !defined?(lcmal_trainerClasses)
$lcmal_trainerClasses['WANDERER']={
  :title => "Omniversal Wanderer",
  :skill => 100,
  :moneymult => 17,
  :battleBGM => "Magical Girl's Crusade.ogg",
  :winBGM => "Victory2",
  :sprites => {
    :fullFigure => 'Data/Mods/libCommonModAssets/Sandbox_trainerXXX_Kalypsa.png',
    :vsBar => 'Data/Mods/libCommonModAssets/Sandbox_vsBarXXX_Kalypsa.png',
    :vsTrainer => 'Data/Mods/libCommonModAssets/Sandbox_vsTrainerXXX_Kalypsa.png'
  }
}

$lcmal_trainers={} if !defined?(lcmal_trainers)
$lcmal_trainers['Potentia'] = {
  :party => [
    {
      TPSPECIES => 129,
      TPLEVEL => 1,
      TPMOVE1 => 410
    },
    {
      TPSPECIES => 31,
      TPLEVEL => 1,
      TPMOVE1 => 419
    },
    {
      TPSPECIES => 34,
      TPLEVEL => 1,
      TPMOVE1 => 364
    },
    {
      TPSPECIES => 62,
      TPLEVEL => 1,
      TPMOVE1 => 383
    },
    {
      TPSPECIES => 189,
      TPLEVEL => 1,
      TPMOVE1 => 410
    },
    {
      TPSPECIES => 45,
      TPLEVEL => 1,
      TPMOVE1 => 212
    }
  ]
}
$lcmal_trainers['Kalypsa'] = {
  :party => [
    {
      TPSPECIES => 452, # Drapion
      TPLEVEL => 100,
      TPGENDER => 0 # M
    },
    {
      TPSPECIES => 208, # Steelix
      TPLEVEL => 100,
      TPITEM => 625 # Steelixite
    },
    {
      TPSPECIES => 655, # Delphox
      TPLEVEL => 100,
      TPGENDER => 0 # M
    },
    {
      TPSPECIES => 462, # Magnezone
      TPLEVEL => 100
    },
    {
      TPSPECIES => 571, # Zoroark
	  TPFORM => 15, # Silvaly's Ice Form
      TPLEVEL => 100,
      TPGENDER => 1, # F
	  TPSHINY => true
    },
    {
      TPSPECIES => 773, # Silvally
	  TPFORM => 15, # Ice Form
      TPLEVEL => 100,
      TPITEM => 698, # Ice Memory
	  TPSHINY => true
    }
  ],
  :items => [
    221, # Full Restore
	221  # Full Restore
  ]
}
$lcmal_trainers['Malerin'] = {
  :party => [
    {
      TPSPECIES => 235,
      TPLEVEL => 100,
	  TPITEM => 114,
      TPMOVE1 => 410
    },
    {
      TPSPECIES => 235,
      TPLEVEL => 100,
	  TPITEM => 114,
      TPMOVE1 => 410
    },
    {
      TPSPECIES => 235,
      TPLEVEL => 100,
	  TPITEM => 114,
      TPMOVE1 => 410
    },
    {
      TPSPECIES => 235,
      TPLEVEL => 100,
	  TPITEM => 114,
      TPMOVE1 => 410
    },
    {
      TPSPECIES => 235,
      TPLEVEL => 100,
	  TPITEM => 114,
      TPMOVE1 => 410
    },
    {
      TPSPECIES => 235,
      TPLEVEL => 100,
	  TPITEM => 114,
      TPMOVE1 => 410
    }
  ]
}

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

# Geneticist
def Sandbox_EditPokemon
  Kernel.pbMessage(_INTL('Hey, listen, I have the ability to modify your pokemon.'))
  Kernel.pbMessage(_INTL("Yo, I'm serious! Lemme show you!"))
  pbFadeOutIn(99999){
    scene=PokemonScreen_Scene.new
    screen=PokemonScreen.new(scene,$Trainer.party)
    screen.pbStartScene(_INTL("Choose a Pokémon."),false)
    chosen=screen.pbChoosePokemon
    screen.Sandbox_pbPokemonDebug($Trainer.party[chosen], chosen) if chosen >= 0
    screen.pbEndScene
  }
  Kernel.pbMessage(_INTL('Smell ya later!'))
end

def Sandbox_pbPokemonDebug(pkmn,pkmnid)
  main_commands={
    _INTL("HP/Status") => 0,
    _INTL("Level") => 1,
    # _INTL("Species") => 2,
    _INTL("Moves") => 3,
    _INTL("Gender") => 4,
    _INTL("Ability") => 5,
    _INTL("Nature") => 6,
    _INTL("Shininess") => 7,
    # _INTL("Form") => 8,
    _INTL("Happiness") => 9,
    _INTL("EV/IV/pID") => 10,
    _INTL("Pokérus") => 11,
    _INTL("Ownership") => 12,
    _INTL("Nickname") => 13,
    _INTL("Poké Ball") => 14,
    # _INTL("Ribbons") => 15,
    _INTL("Egg") => 16,
    # _INTL("Shadow Pokémon") => 17,
    # _INTL("Duplicate") => 18,
    # _INTL("Delete") => 19,
    _INTL("Cancel") => 20
  }
  main_commands_keys=main_commands.keys
  command=0
  loop do
    tmp=@scene.pbShowCommands(_INTL("Do what with {1}?",pkmn.name),main_commands_keys,main_commands_keys.length)
    command=main_commands[main_commands_keys[tmp]]
    case command
      ### Cancel ###
      when -1, 20
        break
      ### HP/Status ###
      when 0
        cmd=0
        loop do
          cmd=@scene.pbShowCommands(_INTL("Do what with {1}?",pkmn.name),[
             _INTL("Set HP"),
             _INTL("Status: Sleep"),
             _INTL("Status: Poison"),
             _INTL("Status: Burn"),
             _INTL("Status: Paralysis"),
             _INTL("Status: Frozen"),
             _INTL("Fainted"),
             _INTL("Heal")
          ],cmd)
          # Break
          if cmd==-1
            break
          # Set HP
          elsif cmd==0
            params=ChooseNumberParams.new
            params.setRange(0,pkmn.totalhp)
            params.setDefaultValue(pkmn.hp)
            newhp=Kernel.pbMessageChooseNumber(
               _INTL("Set the Pokémon's HP (max. {1}).",pkmn.totalhp),params) { @scene.update }
            if newhp!=pkmn.hp
              pkmn.hp=newhp
              pbDisplay(_INTL("{1}'s HP was set to {2}.",pkmn.name,pkmn.hp))
              pbRefreshSingle(pkmnid)
            end
          # Set status
          elsif cmd>=1 && cmd<=5
            if pkmn.hp>0
              pkmn.status=cmd
              pkmn.statusCount=0
              if pkmn.status==PBStatuses::SLEEP
                params=ChooseNumberParams.new
                params.setRange(0,9)
                params.setDefaultValue(0)
                sleep=Kernel.pbMessageChooseNumber(
                   _INTL("Set the Pokémon's sleep count."),params) { @scene.update }
                pkmn.statusCount=sleep
              end
              pbDisplay(_INTL("{1}'s status was changed.",pkmn.name))
              pbRefreshSingle(pkmnid)
            else
              pbDisplay(_INTL("{1}'s status could not be changed.",pkmn.name))
            end
          # Faint
          elsif cmd==6
            pkmn.hp=0
            pbDisplay(_INTL("{1}'s HP was set to 0.",pkmn.name))
            pbRefreshSingle(pkmnid)
          # Heal
          elsif cmd==7
            pkmn.heal
            pbDisplay(_INTL("{1} was fully healed.",pkmn.name))
            pbRefreshSingle(pkmnid)
          end
        end
      ### Level ###
      when 1
        params=ChooseNumberParams.new
        params.setRange(1,PBExperience::MAXLEVEL)
        params.setDefaultValue(pkmn.level)
        level=Kernel.pbMessageChooseNumber(
           _INTL("Set the Pokémon's level (max. {1}).",PBExperience::MAXLEVEL),params) { @scene.update }
        if level!=pkmn.level
          pkmn.level=level
          pkmn.calcStats
          pkmn.poklevel = level
          pbDisplay(_INTL("{1}'s level was set to {2}.",pkmn.name,pkmn.level))
          pbRefreshSingle(pkmnid)
        end
      ### Species ###
      when 2
        species=pbChooseSpecies(pkmn.species)
        if species!=0
          oldspeciesname=PBSpecies.getName(pkmn.species)
          pkmn.species=species
          pkmn.calcStats
          pkmn.exp=PBExperience.pbGetStartExperience(pkmn.level,pkmn.growthrate)
          oldname=pkmn.name
          pkmn.name=PBSpecies.getName(pkmn.species) if pkmn.name==oldspeciesname
          pbDisplay(_INTL("{1}'s species was changed to {2}.",oldname,PBSpecies.getName(pkmn.species)))
          pbSeenForm(pkmn)
          pbRefreshSingle(pkmnid)
        end
      ### Moves ###
      when 3
        cmd=0
        loop do
          cmd=@scene.pbShowCommands(_INTL("Do what with {1}?",pkmn.name),[
             _INTL("Teach move"),
             _INTL("Forget move"),
             _INTL("Reset movelist"),
             _INTL("Reset initial moves")],cmd)
          # Break
          if cmd==-1
            break
          # Teach move
          elsif cmd==0
            move=pbChooseMoveList
            if move!=0
              pbLearnMove(pkmn,move)
              pbRefreshSingle(pkmnid)
            end
          # Forget move
          elsif cmd==1
            move=pbChooseMove(pkmn,_INTL("Choose move to forget."))
            if move>=0
              movename=PBMoves.getName(pkmn.moves[move].id)
              pbDeleteMove(pkmn,move)
              pbDisplay(_INTL("{1} forgot {2}.",pkmn.name,movename))
              pbRefreshSingle(pkmnid)
            end
          # Reset movelist
          elsif cmd==2
            pkmn.resetMoves
            pbDisplay(_INTL("{1}'s moves were reset.",pkmn.name))
            pbRefreshSingle(pkmnid)
          # Reset initial moves
          elsif cmd==3
            pkmn.pbRecordFirstMoves
            pbDisplay(_INTL("{1}'s moves were set as its first-known moves.",pkmn.name))
            pbRefreshSingle(pkmnid)
          end
        end
      ### Gender ###
      when 4
        if pkmn.gender==2
          pbDisplay(_INTL("{1} is genderless.",pkmn.name))
        else
          cmd=0
          loop do
            oldgender=(pkmn.isMale?) ? _INTL("male") : _INTL("female")
            msg=[_INTL("Gender {1} is natural.",oldgender),
                 _INTL("Gender {1} is being forced.",oldgender)][pkmn.genderflag ? 1 : 0]
            cmd=@scene.pbShowCommands(msg,[
               _INTL("Make male"),
               _INTL("Make female"),
               _INTL("Remove override")],cmd)
            # Break
            if cmd==-1
              break
            # Make male
            elsif cmd==0
              pkmn.setGender(0)
              if pkmn.isMale?
                pbDisplay(_INTL("{1} is now male.",pkmn.name))
              else
                pbDisplay(_INTL("{1}'s gender couldn't be changed.",pkmn.name))
              end
            # Make female
            elsif cmd==1
              pkmn.setGender(1)
              if pkmn.isFemale?
                pbDisplay(_INTL("{1} is now female.",pkmn.name))
              else
                pbDisplay(_INTL("{1}'s gender couldn't be changed.",pkmn.name))
              end
            # Remove override
            elsif cmd==2
              pkmn.genderflag=nil
              pbDisplay(_INTL("Gender override removed."))
            end
            pbSeenForm(pkmn)
            pbRefreshSingle(pkmnid)
          end
        end
      ### Ability ###
      when 5
        cmd=0
        loop do
          abils=pkmn.getAbilityList
          oldabil=PBAbilities.getName(pkmn.ability)
          commands=[]
          for i in abils.keys
            commands.push(( i < 2 ? "" : "(H) ")+PBAbilities.getName(abils[i]))
          end
          commands.push(_INTL("Remove override"))
          msg=[_INTL("Ability {1} is natural.",oldabil),
               _INTL("Ability {1} is being forced.",oldabil)][pkmn.abilityflag ? 1 : 0]
          cmd=@scene.pbShowCommands(msg,commands,cmd)
          # Break
          if cmd==-1
            break
          # Set ability override
          elsif cmd>=0 && cmd<abils.length
            pkmn.setAbility(cmd)
          # Remove override
          elsif cmd==abils.length
            pkmn.abilityflag=nil
          end
          pbRefreshSingle(pkmnid)
        end
      ### Nature ###
      when 6
        cmd=0
        loop do
          oldnature=PBNatures.getName(pkmn.nature)
          commands=[]
          (PBNatures.getCount).times do |i|
            commands.push(PBNatures.getName(i))
          end
          commands.push(_INTL("Remove override"))
          msg=[_INTL("Nature {1} is natural.",oldnature),
               _INTL("Nature {1} is being forced.",oldnature)][pkmn.natureflag ? 1 : 0]
          cmd=@scene.pbShowCommands(msg,commands,cmd)
          # Break
          if cmd==-1
            break
          # Set nature override
          elsif cmd>=0 && cmd<PBNatures.getCount
            pkmn.setNature(cmd)
            pkmn.calcStats
          # Remove override
          elsif cmd==PBNatures.getCount
            pkmn.natureflag=nil
          end
          pbRefreshSingle(pkmnid)
        end
      ### Shininess ###
      when 7
        cmd=0
        loop do
          oldshiny=(pkmn.isShiny?) ? _INTL("shiny") : _INTL("normal")
          msg=[_INTL("Shininess ({1}) is natural.",oldshiny),
               _INTL("Shininess ({1}) is being forced.",oldshiny)][pkmn.shinyflag!=nil ? 1 : 0]
          cmd=@scene.pbShowCommands(msg,[
               _INTL("Make shiny"),
               _INTL("Make normal"),
               _INTL("Remove override")],cmd)
          # Break
          if cmd==-1
            break
          # Make shiny
          elsif cmd==0
            pkmn.makeShiny
          # Make normal
          elsif cmd==1
            pkmn.makeNotShiny
          # Remove override
          elsif cmd==2
            pkmn.shinyflag=nil
          end
          pbRefreshSingle(pkmnid)
        end
      ### Form ###
      when 8
        params=ChooseNumberParams.new
        params.setRange(0,100)
        params.setDefaultValue(pkmn.form)
        f=Kernel.pbMessageChooseNumber(
           _INTL("Set the Pokémon's form."),params) { @scene.update }
        if f!=pkmn.form
          pkmn.form=f
          pbDisplay(_INTL("{1}'s form was set to {2}.",pkmn.name,pkmn.form))
          pbSeenForm(pkmn)
          pbRefreshSingle(pkmnid)
        end
      ### Happiness ###
      when 9
        params=ChooseNumberParams.new
        params.setRange(0,255)
        params.setDefaultValue(pkmn.happiness)
        h=Kernel.pbMessageChooseNumber(
           _INTL("Set the Pokémon's happiness (max. 255)."),params) { @scene.update }
        if h!=pkmn.happiness
          pkmn.happiness=h
          pbDisplay(_INTL("{1}'s happiness was set to {2}.",pkmn.name,pkmn.happiness))
          pbRefreshSingle(pkmnid)
        end
      ### EV/IV/pID ###
      when 10
        stats=STATSTRINGS
        cmd=0
        loop do
          persid=sprintf("0x%08X",pkmn.personalID)
          cmd=@scene.pbShowCommands(_INTL("Personal ID is {1}.",persid),[
             _INTL("Set EVs"),
             _INTL("Set IVs"),
             _INTL("Randomise pID")],cmd)
          case cmd
            # Break
            when -1
              break
            # Set EVs
            when 0
              cmd2=0
              loop do
                evcommands=[]
                for i in 0...stats.length
                  evcommands.push(stats[i]+" (#{pkmn.ev[i]})")
                end
                cmd2=@scene.pbShowCommands(_INTL("Change which EV?"),evcommands,cmd2)
                if cmd2==-1
                  break
                elsif cmd2>=0 && cmd2<stats.length
                  params=ChooseNumberParams.new
                  params.setRange(0,255)
                  params.setDefaultValue(pkmn.ev[cmd2])
                  params.setCancelValue(pkmn.ev[cmd2])
                  f=Kernel.pbMessageChooseNumber(
                     _INTL("Set the EV for {1} (max. 255).",stats[cmd2]),params) { @scene.update }
                  pkmn.ev[cmd2]=f
                  pkmn.totalhp
                  pkmn.calcStats
                  pbRefreshSingle(pkmnid)
                end
              end
            # Set IVs
            when 1
              cmd2=0
              loop do
                hiddenpower=pbHiddenPower(pkmn)
                msg=_INTL("Hidden Power:\n{1}",PBTypes.getName(hiddenpower))
                ivcommands=[]
                for i in 0...stats.length
                  ivcommands.push(stats[i]+" (#{pkmn.iv[i]})")
                end
                ivcommands.push(_INTL("Randomise all"))
                cmd2=@scene.pbShowCommands(msg,ivcommands,cmd2)
                if cmd2==-1
                  break
                elsif cmd2>=0 && cmd2<stats.length
                  params=ChooseNumberParams.new
                  params.setRange(0,31)
                  params.setDefaultValue(pkmn.iv[cmd2])
                  params.setCancelValue(pkmn.iv[cmd2])
                  f=Kernel.pbMessageChooseNumber(
                     _INTL("Set the IV for {1} (max. 31).",stats[cmd2]),params) { @scene.update }
                  pkmn.iv[cmd2]=f
                  pkmn.calcStats
                  pbRefreshSingle(pkmnid)
                elsif cmd2==ivcommands.length-1
                  pkmn.iv[0]=rand(32)
                  pkmn.iv[1]=rand(32)
                  pkmn.iv[2]=rand(32)
                  pkmn.iv[3]=rand(32)
                  pkmn.iv[4]=rand(32)
                  pkmn.iv[5]=rand(32)
                  pkmn.calcStats
                  pbRefreshSingle(pkmnid)
                end
              end
            # Randomise pID
            when 2
              pkmn.personalID=rand(256)
              pkmn.personalID|=rand(256)<<8
              pkmn.personalID|=rand(256)<<16
              pkmn.personalID|=rand(256)<<24
              pkmn.calcStats
              pbRefreshSingle(pkmnid)
          end
        end
      ### Pokérus ###
      when 11
        cmd=0
        loop do
          pokerus=(pkmn.pokerus) ? pkmn.pokerus : 0
          msg=[_INTL("{1} doesn't have Pokérus.",pkmn.name),
               _INTL("Has strain {1}, infectious for {2} more days.",pokerus/16,pokerus%16),
               _INTL("Has strain {1}, not infectious.",pokerus/16)][pkmn.pokerusStage]
          cmd=@scene.pbShowCommands(msg,[
               _INTL("Give random strain"),
               _INTL("Make not infectious"),
               _INTL("Clear Pokérus")],cmd)
          # Break
          if cmd==-1
            break
          # Give random strain
          elsif cmd==0
            pkmn.givePokerus
          # Make not infectious
          elsif cmd==1
            strain=pokerus/16
            p=strain<<4
            pkmn.pokerus=p
          # Clear Pokérus
          elsif cmd==2
            pkmn.pokerus=0
          end
        end
      ### Ownership ###
      when 12
        cmd=0
        loop do
          gender=[_INTL("Male"),_INTL("Female"),_INTL("Unknown")][pkmn.otgender]
          msg=[_INTL("Player's Pokémon\n{1}\n{2}\n{3} ({4})",pkmn.ot,gender,pkmn.publicID,pkmn.trainerID),
               _INTL("Foreign Pokémon\n{1}\n{2}\n{3} ({4})",pkmn.ot,gender,pkmn.publicID,pkmn.trainerID)
              ][pkmn.isForeign?($Trainer) ? 1 : 0]
          cmd=@scene.pbShowCommands(msg,[
               _INTL("Make player's"),
               _INTL("Set OT's name"),
               _INTL("Set OT's gender"),
               _INTL("Random foreign ID"),
               _INTL("Set foreign ID")],cmd)
          # Break
          if cmd==-1
            break
          # Make player's
          elsif cmd==0
            pkmn.trainerID=$Trainer.id
            pkmn.ot=$Trainer.name
            pkmn.otgender=$Trainer.gender
          # Set OT's name
          elsif cmd==1
            newot=pbEnterPlayerName(_INTL("{1}'s OT's name?",pkmn.name),1,12)
            pkmn.ot=newot
          # Set OT's gender
          elsif cmd==2
            cmd2=@scene.pbShowCommands(_INTL("Set OT's gender."),
               [_INTL("Male"),_INTL("Female"),_INTL("Unknown")])
            pkmn.otgender=cmd2 if cmd2>=0
          # Random foreign ID
          elsif cmd==3
            pkmn.trainerID=$Trainer.getForeignID
          # Set foreign ID
          elsif cmd==4
            params=ChooseNumberParams.new
            params.setRange(0,65535)
            params.setDefaultValue(pkmn.publicID)
            val=Kernel.pbMessageChooseNumber(
               _INTL("Set the new ID (max. 65535)."),params) { @scene.update }
            pkmn.trainerID=val
            pkmn.trainerID|=val<<16
          end
        end
      ### Nickname ###
      when 13
        cmd=0
        loop do
          speciesname=PBSpecies.getName(pkmn.species)
          msg=[_INTL("{1} has the nickname {2}.",speciesname,pkmn.name),
               _INTL("{1} has no nickname.",speciesname)][pkmn.name==speciesname ? 1 : 0]
          cmd=@scene.pbShowCommands(msg,[
               _INTL("Rename"),
               _INTL("Erase name")],cmd)
          # Break
          if cmd==-1
            break
          # Rename
          elsif cmd==0
            newname=pbEnterPokemonName(_INTL("{1}'s nickname?",speciesname),0,12,"",pkmn)
            pkmn.name=(newname=="") ? speciesname : newname
            pbRefreshSingle(pkmnid)
          # Erase name
          elsif cmd==1
            pkmn.name=speciesname
          end
        end
      ### Poké Ball ###
      when 14
        cmd=0
        loop do
          oldball=PBItems.getName(pbBallTypeToBall(pkmn.ballused))
          commands=[]; balls=[]
          for key in $BallTypes.keys
            item=getID(PBItems,$BallTypes[key])
            balls.push([key,PBItems.getName(item)]) if item && item>0
          end
          balls.sort! {|a,b| a[1]<=>b[1]}
          for i in 0...commands.length
            cmd=i if pkmn.ballused==balls[i][0]
          end
          for i in balls
            commands.push(i[1])
          end
          cmd=@scene.pbShowCommands(_INTL("{1} used.",oldball),commands,cmd)
          if cmd==-1
            break
          else
            pkmn.ballused=balls[cmd][0]
          end
        end
      ### Ribbons ###
      when 15
        cmd=0
        loop do
          commands=[]
          for i in 1..PBRibbons.maxValue
            commands.push(_INTL("{1} {2}",
               pkmn.hasRibbon?(i) ? "[X]" : "[  ]",PBRibbons.getName(i)))
          end
          cmd=@scene.pbShowCommands(_INTL("{1} ribbons.",pkmn.ribbonCount),commands,cmd)
          if cmd==-1
            break
          elsif cmd>=0 && cmd<commands.length
            if pkmn.hasRibbon?(cmd+1)
              pkmn.takeRibbon(cmd+1)
            else
              pkmn.giveRibbon(cmd+1)
            end
          end
        end
      ### Egg ###
      when 16
        cmd=0
        loop do
          msg=[_INTL("Not an egg"),
               _INTL("Egg with eggsteps: {1}.",pkmn.eggsteps)][pkmn.isEgg? ? 1 : 0]
          cmd=@scene.pbShowCommands(msg,[
               _INTL("Make egg"),
               _INTL("Make Pokémon"),
               _INTL("Set eggsteps to 1")],cmd)
          # Break
          if cmd==-1
            break
          # Make egg
          elsif cmd==0
            if pbHasEgg?(pkmn.species) ||
               pbConfirm(_INTL("{1} cannot be an egg. Make egg anyway?",PBSpecies.getName(pkmn.species)))
              pkmn.level=EGGINITIALLEVEL
              pkmn.calcStats
              pkmn.name=_INTL("Egg")
              pkmn.eggsteps=$cache.pkmn_dex[pkmn.species][:EggSteps]
              pkmn.hatchedMap=0
              pkmn.obtainMode=1
              pbRefreshSingle(pkmnid)
            end
          # Make Pokémon
          elsif cmd==1
            pkmn.name=PBSpecies.getName(pkmn.species)
            pkmn.eggsteps=0
            pkmn.hatchedMap=0
            pkmn.obtainMode=0
            pbRefreshSingle(pkmnid)
          # Set eggsteps to 1
          elsif cmd==2
            pkmn.eggsteps=1 if pkmn.eggsteps>0
          end
        end
      ### Shadow Pokémon ###
      when 17
        cmd=0
        loop do
          msg=[_INTL("Not a Shadow Pokémon."),
               _INTL("Heart gauge is {1}.",pkmn.heartgauge)][(pkmn.isShadow? rescue false) ? 1 : 0]
          cmd=@scene.pbShowCommands(msg,[
             _INTL("Make Shadow"),
             _INTL("Lower heart gauge")],cmd)
          # Break
          if cmd==-1
            break
          # Make Shadow
          elsif cmd==0
            if !(pkmn.isShadow? rescue false) && pkmn.respond_to?("makeShadow")
              pkmn.makeShadow
              pbDisplay(_INTL("{1} is now a Shadow Pokémon.",pkmn.name))
              pbRefreshSingle(pkmnid)
            else
              pbDisplay(_INTL("{1} is already a Shadow Pokémon.",pkmn.name))
            end
          # Lower heart gauge
          elsif cmd==1
            if (pkmn.isShadow? rescue false)
              prev=pkmn.heartgauge
              pkmn.adjustHeart(-700)
              Kernel.pbMessage(_INTL("{1}'s heart gauge was lowered from {2} to {3} (now stage {4}).",
                 pkmn.name,prev,pkmn.heartgauge,pkmn.heartStage))
              pbReadyToPurify(pkmn)
            else
              Kernel.pbMessage(_INTL("{1} is not a Shadow Pokémon.",pkmn.name))
            end
          end
        end
      ### Duplicate ###
      when 18
        if pbConfirm(_INTL("Are you sure you want to copy this Pokémon?"))
          clonedpkmn=pkmn.clone
          clonedpkmn.iv=pkmn.iv.clone
          clonedpkmn.ev=pkmn.ev.clone
          pbStorePokemon(clonedpkmn)
          pbHardRefresh
          pbDisplay(_INTL("The Pokémon was duplicated."))
          break
        end
      ### Delete ###
      when 19
        if pbConfirm(_INTL("Are you sure you want to delete this Pokémon?"))
          @party[pkmnid]=nil
          @party.compact!
          pbHardRefresh
          pbDisplay(_INTL("The Pokémon was deleted."))
          break
        end
    end
  end
end

# Pokemon creation
def Sandbox_CreatePokemon
  return Kernel.pbMessage(_INTL('Oh, ok.')) if Kernel.pbMessage(_INTL('I have the ability to generate a specific Pokemon for you.\r\nWould you like me to do this?'), [_INTL('Yes'), _INTL('No')], 2) != 0
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
    # Can also handle Aevian Misdreavus, with the only downside of renaming Alolan to Alternate
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
  # Can also handle Aevian Misdreavus, with the only downside of renaming Alolan to Alternate
  return true
  # # Is this the alternate forms pack mod? Ask drapion!
  # formnames=Sandbox_getFormNames(getID(PBSpecies, :DRAPION))
  # return formnames.length > 1
end

def Sandbox_getFormNames(speciesId)
  formnames=pbGetMessage(MessageTypes::FormNames, speciesId)
  if !formnames || formnames==''
    formnames=['']
  else
    formnames=strsplit(formnames,/,/)
  end
  hasAlolan=false
  idAlternate=-1
  result=[]
  for i in 0...formnames.length
    name=formnames[i].strip
    next if name == ''
    nameDowncase=name.downcase
    hasAlolan=true if nameDowncase=='alolan'
    idAlternate=i if nameDowncase=='alternate'
    result.push([name, i])
  end
  if !hasAlolan && idAlternate >= 0
    # In the base game Alolans are named Alternate
    result[idAlternate][0]='Alolan'
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
      names=['< Cancel >']
      for i in 0...found.length
        names.push(found[i][1])
      end
      i=Kernel.pbMessage(
        _INTL('Found {1} species', found.length),
        names,
        1 # 0 here prevents exiting without making a choice
      )
      return nil if i==0
      return found[i-1][0]
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

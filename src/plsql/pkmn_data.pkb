create or replace PACKAGE BODY PKMN_DATA
AS
	
	/* **************************************************************************************************************** */
	
	FUNCTION get_typing_info(p_pkmn_id NUMBER) RETURN damage_rec_set PIPELINED
	is
	  --vars
      v_pkmn_type1 NUMBER;
      v_pkmn_type2 NUMBER;
      v_type_id TYPES.ID%TYPE;
      v_type_name TYPES.IDENTIFIER%TYPE;
      v_dmg TYPE_EFFICACY.DAMAGE_FACTOR%TYPE;
      v_dmg_type2 TYPE_EFFICACY.DAMAGE_FACTOR%TYPE;
      
      -- types
      TYPE types_row_typ IS TABLE OF TYPES%ROWTYPE;
      v_types_row types_row_typ;
    
      -- cursors
      CURSOR pkmn_types_cur (p_pkmn_id NUMBER, p_slot NUMBER) IS
      	SELECT TYPE_ID
      	FROM POKEMON_TYPES
      	WHERE POKEMON_ID = p_pkmn_id
    	AND SLOT = p_slot;
      
      CURSOR types_cur IS
    	SELECT * 
    	FROM TYPES
    	WHERE ID <= 18; -- 18 main types
    
      CURSOR type_efficacy_cur (p_dmg_type_id TYPE_EFFICACY.DAMAGE_TYPE_ID%TYPE, p_target_type_id TYPE_EFFICACY.TARGET_TYPE_ID%TYPE) IS
      	SELECT DAMAGE_FACTOR
      	FROM TYPE_EFFICACY
      	WHERE DAMAGE_TYPE_ID = p_dmg_type_id
    	AND TARGET_TYPE_ID = p_target_type_id;
	BEGIN
	
      OPEN pkmn_types_cur (p_pkmn_id => p_pkmn_id, p_slot => 1);
      FETCH pkmn_types_cur INTO v_pkmn_type1;
      CLOSE pkmn_types_cur;
      
      OPEN pkmn_types_cur (p_pkmn_id => p_pkmn_id, p_slot => 2);
      FETCH pkmn_types_cur INTO v_pkmn_type2;
      CLOSE pkmn_types_cur;
      
      --DBMS_OUTPUT.PUT_LINE('Type 1: ' || v_pkmn_type1);
      --DBMS_OUTPUT.PUT_LINE('Type 2: ' || v_pkmn_type2);
      
      OPEN types_cur;
      FETCH types_cur BULK COLLECT INTO v_types_row;
      CLOSE types_cur;
      
      FOR i IN 1..v_types_row.COUNT LOOP -- always 1 row
    	v_type_id := v_types_row(i).ID;
    	v_type_name := v_types_row(i).IDENTIFIER;
    	
    	IF v_pkmn_type2 IS NULL THEN -- pkmn with 1 type
    	  
    	  OPEN type_efficacy_cur (p_dmg_type_id => v_type_id, p_target_type_id => v_pkmn_type1);
    	  FETCH type_efficacy_cur INTO v_dmg;
    	  CLOSE type_efficacy_cur;
    	  
    	  IF v_dmg > 0 THEN
    	    v_dmg := v_dmg / 100 ; -- set damage to 0.5, 1, 2...
    	  END IF;
    	  
    	  --DBMS_OUTPUT.PUT_LINE('v_type_name: ' || v_type_name || ' v_dmg: '|| v_dmg);
		  PIPE ROW (damage_rec_typ(v_dmg,v_type_name));
    	
    	ELSE -- pkmn with 2 types
    	
    	  OPEN type_efficacy_cur (p_dmg_type_id => v_type_id, p_target_type_id => v_pkmn_type1);
    	  FETCH type_efficacy_cur INTO v_dmg;
    	  CLOSE type_efficacy_cur;
    	  
    	  IF v_dmg > 0 THEN
    	    v_dmg := v_dmg / 100 ; -- set damage to 0.5, 1, 2...
    	  END IF;
    	  
    	  OPEN type_efficacy_cur (p_dmg_type_id => v_type_id, p_target_type_id => v_pkmn_type2);
    	  FETCH type_efficacy_cur INTO v_dmg_type2;
    	  CLOSE type_efficacy_cur;
    	  
    	  IF v_dmg_type2 > 0 THEN
    	    v_dmg_type2 := v_dmg_type2 / 100 ; -- set damage to 0.5, 1, 2...
    	  END IF;
    	  
    	  -- Combine the 2 damages
    	  CASE 
    		WHEN v_dmg = 0 or v_dmg_type2 = 0 then -- 0x
    		  v_dmg := v_dmg * v_dmg_type2; -- NO change
    		WHEN v_dmg = 0.5 and v_dmg_type2 = 0.5 then -- 0.25x
    		  v_dmg := v_dmg * v_dmg_type2;
    		WHEN v_dmg = 2 and v_dmg_type2 = 2 then -- 4x
    		  v_dmg := v_dmg * v_dmg_type2;
    		WHEN (v_dmg = 2 and v_dmg_type2 = 0.5) or (v_dmg = 0.5 and v_dmg_type2 = 2) then -- 1x
    		  v_dmg := v_dmg * v_dmg_type2;
    		WHEN (v_dmg != 2 and v_dmg_type2 = 0.5) or (v_dmg = 0.5 and v_dmg_type2 != 2) then -- 0.5x
    		  v_dmg := 0.5;
    		WHEN (v_dmg = 2 and v_dmg_type2 != 0.5) or (v_dmg != 0.5 and v_dmg_type2 = 2) then -- 0x
    		  v_dmg := 2;
    		ELSE -- 1x
    		  v_dmg := 1;
    	  END CASE;
    	  
    	  --DBMS_OUTPUT.PUT_LINE('v_type_name: ' || v_type_name || ' v_dmg: '|| v_dmg);
		  PIPE ROW (damage_rec_typ(v_dmg,v_type_name));
		  
    	END IF;
      END LOOP;

	EXCEPTION
	  WHEN OTHERS THEN
		-- Handle exceptions
		DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
	
		-- Close the cursor if it's still open
		IF types_cur%ISOPEN THEN
		  CLOSE types_cur;
		END IF;
		
		IF pkmn_types_cur%ISOPEN THEN
		  CLOSE pkmn_types_cur;
		END IF;
		
		IF type_efficacy_cur%ISOPEN THEN
		  CLOSE type_efficacy_cur;
		END IF;
	
	END get_typing_info;

	FUNCTION get_evolution_info(p_evo_chain_id NUMBER) RETURN evolution_rec_set PIPELINED
	is
		--vars
		v_pkmn_id POKEMON_SPECIES.ID%TYPE;
		v_evo_trigger_id POKEMON_EVOLUTION.EVOLUTION_TRIGGER_ID%TYPE;
		v_evo_trigger_name EVOLUTION_TRIGGERS.IDENTIFIER%TYPE;
		v_evo_description VARCHAR2(4000);
		-- vars for cursor results
		v_item_name ITEM_NAMES.NAME%TYPE;
		v_move_name MOVE_NAMES.NAME%TYPE;
		v_type_name TYPES.IDENTIFIER%TYPE;
		v_party_species_name POKEMON_SPECIES.IDENTIFIER%TYPE;
		v_party_type_name TYPES.IDENTIFIER%TYPE;
		v_location_name LOCATION_NAMES.NAME%TYPE;
		
		evolution_rec evolution_rec_typ;
		
		-- types
		TYPE pkmn_evo_row_type IS TABLE OF POKEMON_EVOLUTION%ROWTYPE;
		v_evo_row pkmn_evo_row_type;
		
		-- cursors
		CURSOR pkmn_species_cur (p_evo_chain_id POKEMON_SPECIES.EVOLUTION_CHAIN_ID%TYPE) IS
			SELECT ID
			FROM POKEMON_SPECIES
			WHERE EVOLUTION_CHAIN_ID = p_evo_chain_id
			order by ID;
		
		CURSOR pkmn_evolution_cur (p_pkmn_id POKEMON_EVOLUTION.EVOLVED_SPECIES_ID%TYPE) IS
			SELECT * 
			FROM POKEMON_EVOLUTION
			WHERE EVOLVED_SPECIES_ID = p_pkmn_id;
		
		CURSOR evo_triggers_cur (p_evo_trigger_id EVOLUTION_TRIGGERS.ID%TYPE) IS
			SELECT IDENTIFIER
			FROM EVOLUTION_TRIGGERS
			WHERE ID = p_evo_trigger_id;
		
		CURSOR items_cur (p_item_id ITEMS.ID%TYPE) IS
			SELECT 
			CASE
				WHEN itn.NAME IS NOT NULL THEN itn.NAME
				ELSE REPLACE(INITCAP(i.IDENTIFIER),'-',' ')
			END AS ITEM_NAME
			FROM ITEMS i
			LEFT JOIN ITEM_NAMES itn ON i.ID = itn.ITEM_ID
			WHERE i.ID = p_item_id;
		
		CURSOR moves_cur (p_move_id ITEMS.ID%TYPE) IS
			SELECT NAME
			FROM MOVE_NAMES
			WHERE MOVE_ID = p_move_id;
		
		CURSOR types_cur (p_type_id TYPES.ID%TYPE) IS
			SELECT IDENTIFIER
			FROM TYPES
			WHERE ID = p_type_id;
		
		CURSOR species_cur (p_species_id POKEMON_SPECIES.ID%TYPE) IS
			SELECT IDENTIFIER
			FROM POKEMON_SPECIES
			WHERE ID = p_species_id;
		
		CURSOR location_cur (p_location_id ITEMS.ID%TYPE) IS
			SELECT NAME
			FROM LOCATION_NAMES
			WHERE LOCATION_ID = p_location_id;

	BEGIN
	  
	  -- Open the cursor
	  OPEN pkmn_species_cur(p_evo_chain_id => p_evo_chain_id);
	  
	  -- Fetch rows from the cursor into variables
	  LOOP
		FETCH pkmn_species_cur INTO v_pkmn_id;
		
		-- Exit the loop if no more rows are found
		EXIT WHEN pkmn_species_cur%NOTFOUND;
		DBMS_OUTPUT.PUT_LINE('####################################################');
		DBMS_OUTPUT.PUT_LINE('v_pkmn_id: ' || v_pkmn_id);
		
		OPEN pkmn_evolution_cur(p_pkmn_id => v_pkmn_id);
		FETCH pkmn_evolution_cur BULK COLLECT INTO v_evo_row;
		--DBMS_OUTPUT.PUT_LINE('v_evo_row.COUNT: '||to_char(v_evo_row.COUNT));
		CLOSE pkmn_evolution_cur;
		
		IF v_evo_row.COUNT > 0 THEN
		
		  FOR i IN 1..v_evo_row.COUNT LOOP -- always 1 row
			v_evo_trigger_id := v_evo_row(1).EVOLUTION_TRIGGER_ID;
		  END LOOP;
		  --
		  OPEN evo_triggers_cur (p_evo_trigger_id => v_evo_trigger_id);
		  FETCH evo_triggers_cur INTO v_evo_trigger_name;
		  DBMS_OUTPUT.PUT_LINE('v_evo_trigger_name: ' || v_evo_trigger_name);
		  CLOSE evo_triggers_cur;
		  
		  -- v_pkmn_id (value from POKEMON_EVOLUTION.EVOLVED_SPECIES_ID)
		  CASE
			-- ------------------- 'level-up' ----------------------------------------
			WHEN v_evo_trigger_name = 'level-up' THEN
			  
			  IF v_evo_row(1).MINIMUM_LEVEL is not null THEN
				v_evo_description := 'Level '||v_evo_row(1).MINIMUM_LEVEL;
			  ELSE
				v_evo_description := 'Level Up';
			  END IF;
			  
			  IF v_evo_row(1).GENDER_ID is not null THEN
				IF v_evo_row(1).GENDER_ID = 2 THEN
				  v_evo_description := v_evo_description||' (Male)';
				ELSE
				  v_evo_description := v_evo_description||' (Female)';
				END IF;
			  END IF;
			  
			  IF v_evo_row(1).HELD_ITEM_ID is not null THEN
				OPEN items_cur (p_item_id => v_evo_row(1).HELD_ITEM_ID);
				FETCH items_cur INTO v_item_name;
				CLOSE items_cur;
				v_evo_description := v_evo_description||' holding '||v_item_name;
			  END IF;
			  
			  IF v_evo_row(1).KNOWN_MOVE_ID is not null THEN
				OPEN moves_cur (p_move_id => v_evo_row(1).KNOWN_MOVE_ID);
				FETCH moves_cur INTO v_move_name;
				CLOSE moves_cur;
				v_evo_description := v_evo_description||' knowing '||v_move_name;
			  END IF;
			  
			  IF v_evo_row(1).KNOWN_MOVE_TYPE_ID is not null THEN
				OPEN types_cur (p_type_id => v_evo_row(1).KNOWN_MOVE_TYPE_ID);
				FETCH types_cur INTO v_type_name;
				CLOSE types_cur;
				v_evo_description := v_evo_description||' knowing a '||v_type_name||' move';
			  END IF;
			  
			  IF v_evo_row(1).MINIMUM_HAPPINESS is not null THEN
				v_evo_description := v_evo_description||' with '||v_evo_row(1).MINIMUM_HAPPINESS||' Happiness';
			  END IF;
			  
			  IF v_evo_row(1).MINIMUM_BEAUTY is not null THEN
				v_evo_description := v_evo_description||' with '||v_evo_row(1).MINIMUM_BEAUTY||' Beauty';
			  END IF;
			  
			  IF v_evo_row(1).MINIMUM_AFFECTION is not null THEN
				v_evo_description := v_evo_description||' with '||v_evo_row(1).MINIMUM_AFFECTION||' Affection';
			  END IF;
			  
			  IF v_evo_row(1).RELATIVE_PHYSICAL_STATS is not null THEN
				IF v_evo_row(1).RELATIVE_PHYSICAL_STATS = 1 THEN
				  v_evo_description := v_evo_description||' with Attack > Defense';
				ELSIF v_evo_row(1).RELATIVE_PHYSICAL_STATS = -1 THEN
				  v_evo_description := v_evo_description||' with Attack < Defense';
				ELSE
				  v_evo_description := v_evo_description||' with Attack = Defense';
				END IF;
			  END IF;
			  
			  IF v_evo_row(1).PARTY_SPECIES_ID is not null THEN
				OPEN species_cur (p_species_id => v_evo_row(1).PARTY_SPECIES_ID);
				FETCH species_cur INTO v_party_species_name;
				CLOSE species_cur;
				v_evo_description := v_evo_description||' with '||v_party_species_name||' in party';
			  END IF;
			  
			  IF v_evo_row(1).PARTY_TYPE_ID is not null THEN
				OPEN types_cur (p_type_id => v_evo_row(1).PARTY_TYPE_ID);
				FETCH types_cur INTO v_party_type_name;
				CLOSE types_cur;
				v_evo_description := v_evo_description||' with '||v_party_type_name||' type in party';
			  END IF;
			  
			  IF v_evo_row(1).LOCATION_ID is not null THEN
				OPEN location_cur (p_location_id => v_evo_row(1).LOCATION_ID);
				FETCH location_cur INTO v_location_name;
				CLOSE location_cur;
				v_evo_description := v_evo_description||' at '||v_location_name;
			  END IF;
			  
			  IF v_evo_row(1).NEEDS_OVERWORLD_RAIN != 0 THEN
				v_evo_description := v_evo_description||' during Rain';
			  END IF;
			  
			  IF v_evo_row(1).TIME_OF_DAY is not null THEN
				v_evo_description := v_evo_description||' at '||v_evo_row(1).TIME_OF_DAY||'time';
			  END IF;
			  
			  IF v_evo_row(1).TURN_UPSIDE_DOWN != 0 THEN
				v_evo_description := v_evo_description||' holding 3DS upside-down';
			  END IF;
			  
			  
			-- ------------------- 'trade' ----------------------------------------
			WHEN v_evo_trigger_name = 'trade' THEN
			  v_evo_description := 'Trade';
			  
			  IF v_evo_row(1).HELD_ITEM_ID is not null THEN
				OPEN items_cur (p_item_id => v_evo_row(1).HELD_ITEM_ID);
				FETCH items_cur INTO v_item_name;
				CLOSE items_cur;
				v_evo_description := v_evo_description||' holding '||v_item_name;
			  END IF;
			  
			  IF v_evo_row(1).TRADE_SPECIES_ID is not null THEN
				OPEN species_cur (p_species_id => v_evo_row(1).TRADE_SPECIES_ID);
				FETCH species_cur INTO v_party_species_name;
				CLOSE species_cur;
				v_evo_description := v_evo_description||' with '||v_party_species_name;
			  END IF;
			  
			  IF v_evo_row(1).GENDER_ID is not null THEN
				IF v_evo_row(1).GENDER_ID = 2 THEN
				  v_evo_description := v_evo_description||' (Male)';
				ELSE
				  v_evo_description := v_evo_description||' (Female)';
				END IF;
			  END IF;
			  
			-- ------------------- 'use-item' ----------------------------------------
			WHEN v_evo_trigger_name = 'use-item' THEN
			  v_evo_description := 'Use';
			  
			  IF v_evo_row(1).TRIGGER_ITEM_ID is not null THEN
				OPEN items_cur (p_item_id => v_evo_row(1).TRIGGER_ITEM_ID);
				FETCH items_cur INTO v_item_name;
				CLOSE items_cur;
				v_evo_description := v_evo_description||' '||v_item_name;
			  END IF;
			
			-- ------------------- 'shed' ----------------------------------------
			WHEN v_evo_trigger_name = 'shed' THEN
			  v_evo_description := 'Level 20, with empty PokéBall and an open slot in party';
			
			-- ------------------- 'spin' ----------------------------------------
			WHEN v_evo_trigger_name = 'spin' THEN
			  v_evo_description := 'Spin holding a Sweet';
			
			-- ------------------- 'tower-of-darkness' ----------------------------------------
			WHEN v_evo_trigger_name = 'Train in the Tower of Darkness' THEN
			  v_evo_description := 'Trade';
			
			-- ------------------- 'tower-of-waters' ----------------------------------------
			WHEN v_evo_trigger_name = 'tower-of-waters' THEN
			  v_evo_description := 'Train in the Tower of Waters';
			
			-- ------------------- 'three-critical-hits' ----------------------------------------
			WHEN v_evo_trigger_name = 'three-critical-hits' THEN
			  v_evo_description := 'Land three critical hits in a battle';
			
			-- ------------------- 'take-damage' ----------------------------------------
			WHEN v_evo_trigger_name = 'take-damage' THEN
			  v_evo_description := 'Travel under the stone bridge in Dusty Bowl after taking at least 49 HP in damage from attacks without fainting';
			
			-- ------------------- 'agile-style-move' ----------------------------------------
			WHEN v_evo_trigger_name = 'agile-style-move' THEN
			  v_evo_description := 'Use 20 times';
			  
			  IF v_evo_row(1).KNOWN_MOVE_ID is not null THEN
				OPEN moves_cur (p_move_id => v_evo_row(1).KNOWN_MOVE_ID);
				FETCH moves_cur INTO v_move_name;
				CLOSE moves_cur;
				v_evo_description := v_evo_description||' '||v_move_name||' in Agile Style';
			  END IF;
			
			-- ------------------- 'strong-style-move' ----------------------------------------
			WHEN v_evo_trigger_name = 'strong-style-move' THEN
			  v_evo_description := 'Use 20 times';
			  
			  IF v_evo_row(1).KNOWN_MOVE_ID is not null THEN
				OPEN moves_cur (p_move_id => v_evo_row(1).KNOWN_MOVE_ID);
				FETCH moves_cur INTO v_move_name;
				CLOSE moves_cur;
				v_evo_description := v_evo_description||' '||v_move_name||' in Strong Style';
			  END IF;
			
			-- ------------------- 'recoil-damage' ----------------------------------------
			WHEN v_evo_trigger_name = 'recoil-damage' THEN
			  v_evo_description := 'Level Up after losing at least 294 PS from Recoil damage without fainting';
			
			-- ------------------- 'other' ----------------------------------------
			WHEN v_evo_trigger_name = 'other' THEN
			  
			  IF v_evo_row(1).MINIMUM_LEVEL is not null THEN
				v_evo_description := 'Level '||v_evo_row(1).MINIMUM_LEVEL;
			  ELSE
				v_evo_description := 'Level Up';
			  END IF;
			  
			  case 
				when v_pkmn_id = 923 then -- pawmot
				  v_evo_description := 'Level Up taking 1000 steps with it in Let''s Go mode';
				when v_pkmn_id = 925 then -- maushold
				  v_evo_description := v_evo_description||' in a battle';
				when v_pkmn_id = 947 then -- bramblin
				  v_evo_description := 'Level Up taking 1000 steps with it in Let''s Go mode';
				when v_pkmn_id = 954 then -- rabsca
				  v_evo_description := 'Level Up taking 1000 steps with it in Let''s Go mode';
				when v_pkmn_id = 964 then -- palafin
				  v_evo_description := v_evo_description||' while in a Union Circle group';
				when v_pkmn_id = 979 then -- annihilape
				  v_evo_description := 'Level Up after using Rage Fist 20 times';
				when v_pkmn_id = 983 then -- kingambit
				  v_evo_description := 'Level Up after defeating 3 Bisharp that hold a Leader''s Crest';
				when v_pkmn_id = 1000 then
				  v_evo_description := 'Level Up with 999 Gimmighoul Coins in the Bag';
			  end case;
			
			-- ------------------- 'error' ----------------------------------------
			ELSE
			  v_evo_description := 'ERROR. Value is unknown';
		  END CASE;
		  -- Print description at the END
		  DBMS_OUTPUT.PUT_LINE('v_evo_description: ' || v_evo_description);
		ELSE
		  DBMS_OUTPUT.PUT_LINE('First PKMN of the evolution chain. Nothing to do...');
		  v_evo_description := NULL;
		END IF;
		
		-- Create record
		evolution_rec.pkmn_id := v_pkmn_id;
		evolution_rec.evo_desc := v_evo_description;
		PIPE ROW (evolution_rec);

	  END LOOP;
	  -- Close the cursor
	  CLOSE pkmn_species_cur;

	EXCEPTION
	  WHEN OTHERS THEN
		-- Handle exceptions
		DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
		
		-- Close the cursor if it's still open
		IF pkmn_species_cur%ISOPEN THEN
		  CLOSE pkmn_species_cur;
		END IF;
		IF pkmn_evolution_cur%ISOPEN THEN
		  CLOSE pkmn_evolution_cur;
		END IF;
		IF evo_triggers_cur%ISOPEN THEN
		  CLOSE evo_triggers_cur;
		END IF;
		IF items_cur%ISOPEN THEN
		  CLOSE items_cur;
		END IF;
		IF moves_cur%ISOPEN THEN
		  CLOSE moves_cur;
		END IF;
		IF types_cur%ISOPEN THEN
		  CLOSE types_cur;
		END IF;
		IF species_cur%ISOPEN THEN
		  CLOSE species_cur;
		END IF;
		
		--
		IF location_cur%ISOPEN THEN
		  CLOSE location_cur;
		END IF;

	end get_evolution_info;	

end PKMN_DATA;
/
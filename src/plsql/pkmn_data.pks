create or replace PACKAGE PKMN_DATA
AS
	
	-- types
	TYPE damage_rec_typ IS RECORD (
		damage_from  NUMBER,
		pkmn_type	 TYPES.IDENTIFIER%TYPE
	);
	TYPE damage_rec_set IS TABLE OF damage_rec_typ;
	
	TYPE pokemon_types IS TABLE OF VARCHAR2(50);
	
	TYPE evolution_rec_typ IS RECORD (
		pkmn_id  NUMBER,
		evo_desc VARCHAR2(50)
	);
	TYPE evolution_rec_set IS TABLE OF evolution_rec_typ;
	
	-- functions
	FUNCTION get_typing_info(p_pkmn_id NUMBER) RETURN damage_rec_set PIPELINED;
	FUNCTION get_evolution_info(p_evo_chain_id NUMBER) RETURN evolution_rec_set PIPELINED;
	
end PKMN_DATA;
/
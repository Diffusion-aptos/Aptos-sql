module aptos_sql::gate {

    use std::string;
    use std::string::{String, utf8};
    use std::vector;
    use std::vector::{reverse, contains};
    use aptos_std::debug;
    use aptos_framework::account::create_resource_address;
    use aptos_framework::object;
    use aptos_sql::sql_struct::{Root_node, search_all_node_without_information};
    #[test_only]
    use aptos_sql::sql_struct::{call_init};

    const Seed :vector<u8> = b"aptos_SQL";
    // =========== error code =========== //
    const E_not_SQL : u64 = 1;
    const E_SELECT_wrong:u64 =2;
    const E_From_wrong:u64 =3;
    // =========== error code =========== //

    public entry fun sql_gate( sql:String){
       // debug::print(&utf8(b"string"));
        // debug::print(&string::sub_string(&sql,0,6));
         //debug::print(&string::sub_string(&sql,7,8));
        //debug::print(&string::sub_string(&sql,9,13));
        select(sql);

    }
    public entry fun insert_new_tables(caller:&signer){

    }


    // =========== sql grammar =========== //
    fun select(input:String){
        let sting_input = string::sub_string(&input,0,6);
        assert!(sting_input == utf8(b"SELECT"),E_SELECT_wrong);
        star(input);
    }
    fun star(input:String){
        let sting_input1 = string::sub_string(&input,6,7);
        assert!(sting_input1 == utf8(b" "),E_not_SQL);
        let space_index =find_space(string::sub_string(&input,7,vector::length(string::bytes(&input))));
        let find_place = string::sub_string(&input,7,7+space_index);
        assert!(string::sub_string(&input,7+space_index,7+space_index+1) == utf8(b" "),E_not_SQL);
        if(find_place == utf8(b"*")){
                assert!(string::sub_string(&input,8+space_index,12+space_index) == utf8(b"FROM"),E_From_wrong);
                assert!(string::sub_string(&input,12+space_index,13+space_index) == utf8(b" "),E_not_SQL);
                debug::print(&utf8(b"form place index"));
                debug::print(&string::sub_string(&input,13+space_index,vector::length(string::bytes(&input))));
                let form_placr_index = find_space(string::sub_string(&input,13+space_index,vector::length(string::bytes(&input))));
                let form_place =string::sub_string(&input,13+space_index,13+space_index+form_placr_index);
                let return_vector = search_all_node_without_information(form_place);
                debug::print(&form_place);
        }else{
            // debug::print();
        }
    }

    // =========== test =================== //
    #[test(caller=@aptos_sql)]
    fun test_select ( caller:&signer){
        call_init(caller);
        sql_gate(utf8(b"SELECT * FROM XABcc where"))
    }


    // =========== logic =================== //
    fun find_space(input:String):u64{
        let v_u8=string::bytes(&input);
        let (true_or_not,index)=vector::find(v_u8,|in| find_sapce_1(in));
        // debug::print(&utf8(b"true or not"));
        // debug::print(&true_or_not);
        // debug::print(&utf8(b"index"));
        // debug::print(&index);
        index
    }
    fun find_sapce_1(input:&u8):bool{
        // debug::print(input);
        // debug::print(vector::borrow(&b" ",0));
       input == vector::borrow(&b" ",0)
    }
    // =========== Search  =================== //


}

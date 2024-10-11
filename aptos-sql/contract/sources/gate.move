module aptos_sql::gate {

    use std::string;
    use std::string::{String, utf8};
    use std::vector;
    use std::vector::{reverse, contains};
    use aptos_std::debug;

    // =========== error code =========== //
    const E_not_SQL : u64 = 1;
    const E_SELECT_wrong:u64 =2;
    // =========== error code =========== //

    public entry fun sql_gate(caller:&signer, sql:String){
       // debug::print(&utf8(b"string"));
        // debug::print(&string::sub_string(&sql,0,6));
         //debug::print(&string::sub_string(&sql,7,8));
        // debug::print(&string::sub_string(&sql,9,13));
        select(sql);
        star(sql);
    }


    // =========== sql grammar =========== //
    fun select(input:String){
        let sting_input = string::sub_string(&input,0,6);
        assert!(sting_input == utf8(b"SELECT"),E_SELECT_wrong);
    }
    fun star(input:String){
        let sting_input1 = string::sub_string(&input,6,7);
        assert!(sting_input1 == utf8(b" "),E_not_SQL);
        let space_index =find_space(string::sub_string(&input,7,vector::length(string::bytes(&input))));
        let find_place = string::sub_string(&input,7,7+space_index);
        assert!(string::sub_string(&input,7+space_index,7+space_index+1) == utf8(b" "),E_not_SQL);
        if(find_place == utf8(b"*")){
            
        }else{

        }
    }
    // =========== test =================== //
    #[test(caller=@aptos_sql)]
    fun test_select ( caller:&signer){

        sql_gate(caller,utf8(b"SELECT * FROM XAB WHERE"))
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
}

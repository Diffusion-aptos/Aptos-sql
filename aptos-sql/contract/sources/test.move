
module aptos_sql::test {

    #[test_only]
    use std::string::{utf8, String};
    #[test_only]
    use std::vector;
    #[test_only]
    use aptos_sql::gate::{sql_gate, insert_new_tables};
    #[test_only]
    use aptos_sql::sql_struct::{call_init, struct_call_collision_init, print_root_tree, print_object_store,print_table_data_all_key,
        print_table_data_table_v2
    };


    // ================== test sql select ================== //
    #[test(caller=@aptos_sql)]
    fun test_select ( caller:&signer){
        call_init(caller);
        sql_gate(utf8(b"SELECT * FROM XABcc where"));
    }
    // ================== test sql select ================== //
    // ================== test sql insert ================== //
    #[test(caller=@aptos_sql)]
    fun test_insert (caller:&signer){
        call_init(caller);
        struct_call_collision_init();

        let a_v = vector::empty<String>();
        vector::push_back(&mut a_v,utf8(b"data1"));
        vector::push_back(&mut a_v,utf8(b"data2"));
        vector::push_back(&mut a_v,utf8(b"data3"));
        vector::push_back(&mut a_v,utf8(b"data4"));
        vector::push_back(&mut a_v,utf8(b"data5"));

        insert_new_tables(caller,utf8(b"table1"),a_v);


        // print_root_tree();
        // print_object_store();
        // print_table_data_all_key();
        // print_table_data_table_v2();
    }
    // ================== test sql insert ================== //



}

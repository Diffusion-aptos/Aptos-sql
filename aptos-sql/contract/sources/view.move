module aptos_sql::view{

    use std::string::String;
    use std::vector;
    use aptos_sql::gate::sql_gate;

    #[view]
    public fun check_table(sql:String):vector<String>{
        sql_gate(sql);
        vector::empty<String>()
    }
}

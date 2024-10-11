module aptos_sql::sql_struct {

    use std::option::Option;
    use std::string::String;
    use aptos_std::smart_table;
    use aptos_std::smart_vector;
    use aptos_std::smart_vector::SmartVector;
    use aptos_framework::account::{create_resource_account, SignerCapability};
    use aptos_framework::object::Object;


    const Seed :vector<u8> = b"aptos_SQL";

    struct Resouces_cap has key {
        cap:SignerCapability
    }

    struct Table_v2 has key ,store{
        table_id:u64,
        store:String,
        pointer_y:Option<Table_v1>
    }
    struct Table_v1 has key ,store{
        x:u64,
        y:u64,
        ponter_x:Option<u64>
    }
    struct Object_store has key{
        is_leaf:u8,
        id_leaf:u64,
        key_word:String,
        next_one:Option<address>,
        store:smart_table::SmartTable<Table_v1,Table_v2>
    }
    struct Leaf_key has key,store{
        id:u64,
        key_word:String,
        key_address:Object<Object_store>
    }
    struct Leaf_node has key,store{
        is_leaf:u8,
        id_start:u64,
        id_end:u64,
        key_word_store:smart_vector::SmartVector<Leaf_key>
    }
    struct Root_node has key{
        entry_number:u64,
        children:SmartVector<Leaf_node>
    }

    fun init_module(caller:&signer){
        let (resoures_signer,resources_signer_cap)=create_resource_account(caller,Seed);
        move_to(&resoures_signer,Resouces_cap{cap:resources_signer_cap});
    }
}

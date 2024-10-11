module aptos_sql::sql_struct {

    use std::option;
    use std::option::Option;
    use std::string::{String, utf8};
    use aptos_std::debug;
    use aptos_std::smart_table;
    use aptos_std::smart_vector;
    use aptos_std::smart_vector::SmartVector;
    use aptos_framework::account::{create_resource_account, SignerCapability};
    use aptos_framework::object;
    use aptos_framework::object::{Object, DeleteRef, ExtendRef, TransferRef, create_object_address};
    use aptos_framework::account::create_resource_address;


    const Seed :vector<u8> = b"aptos_SQL";

    // Useful const
    const Max_Level:u64 = 3; // Max layer of node
    const Max_Organ:u64 = 3; // Max leaf key
    const Id_range:u64 = 40; // Leaf node id range

    // ============ ability ============ //
    struct Obj_cap has key,store{
        del_ref : Option<DeleteRef>,
        extend_ref:ExtendRef,
        trans_ref : TransferRef
    }

    struct Resouces_cap has key {
        cap:SignerCapability
    }
    // ============ ability ============ //

    // Table v1 and Table v2 is somekind like excel
    // Table v1 - (x,y)->(data)
    // Table v2 - store data and point to next table v1
    // Table v1 ->                         sample
    // |==========================================||=======================================| //
    // |("Excel 1",1,1,1) , (1,"a",v1 -> (2,1))   ||("Excel 1",1,2,12),(11,"d",v1 -> (2,2))| //
    // |==========================================||=======================================| //
    // |("Excel 1",2,1,2) , (2,"b",v1 -> (3,1))   ||("Excel 1",2,2,13),(12,"e",v1 -> (3,2))| //
    // |==========================================||=======================================| //
    // |......................................... ||.......................................| //
    // |==========================================||=======================================| //
    // |("Excel 1",10,1,11 ), (10,"c",v1 -> (1,2))||("Excel 1",10,2,21),(20,"f",v1 ->(1,3))| //
    // |==========================================||=======================================| //
    struct Table_v2 has key ,store{
        table_id:u64,
        store:String,
        pointer_y:Option<Table_v1>
    }
    struct Table_v1 has key ,store{
        table_name:String,
        x:u64,
        y:u64,
        ponter_v2_id:Option<u64>
    }
    struct Object_store has key{
        is_leaf:u8,          // is_leaf - 1/0 - leaf/nonleaf
        own_leaf_id:u64,    // which leaf does this belong to?
        next_leaf:Option<address>,  // leaf -> leaf , which leaf be the next one
        obj_store_id:u64,   // own object id
        next_obj_store_id:u64,  // object -> object , which object be the next one
        key_word:String,
        store:smart_table::SmartTable<Table_v1,Table_v2>       // store data
    }
    //
    struct Leaf_key has key,store{
        id:u64,
        key_word:smart_vector::SmartVector<String>,
        key_address:Object<Object_store>
    }
    // non-leaf or leaf node
    // is_leaf -> 0 (non-leaf)
    // is_leaf -> 1 (leaf)
    // id_end - id_start = Id_range
    // key_word_store store next Leaf key
    struct Leaf_node has key,store{
        is_leaf:u8,
        id_start:u64,
        id_end:u64,
        key_word_store:smart_vector::SmartVector<Leaf_key>
    }
    // Root entry of all
    struct Root_node has key{
        entry_number:u64,
        children:SmartVector<Leaf_node>
    }

    //init for aptos sql
    fun init_module(caller:&signer) acquires Root_node {
        init_step_1(caller);
        init_step_2(caller)
    }



    //=====================test=========================//

    #[test(caller=@aptos_sql)]
    fun test_init(caller:&signer) acquires Root_node {
        init_module(caller);
        //print_obj()
    }

    //=====================test=========================//

    public fun print_obj () acquires Root_node {
        // debug::print(&utf8(b"Generate object address"));
        // debug::print(&object::create_object_address(&create_resource_address(&@aptos_sql,Seed ),Seed));
        // debug::print(&utf8(b"object leaf node"));
        // debug::print(&object::address_to_object<Root_node>(object::create_object_address(&create_resource_address(&@aptos_sql,Seed ),Seed)));
        debug::print(&utf8(b"root leaf node"));
        debug::print(borrow_global<Root_node>(object::create_object_address(&create_resource_address(&@aptos_sql,Seed ),Seed)));
    }

    //===================== init fun =========================//

    // Generta resources address to be the owner of root named object
    // Generate a named object to be empty entry root
    fun init_step_1(caller:&signer){
        let (resoures_signer,resources_signer_cap)=create_resource_account(caller,Seed);
        move_to(&resoures_signer,Resouces_cap{cap:resources_signer_cap});
        let obj_cont = object::create_named_object(&resoures_signer,Seed);
        let del_ref1 = option::none<DeleteRef>();
        let trans_ref1 = object::generate_transfer_ref(&obj_cont);
        object::disable_ungated_transfer(&trans_ref1);
        let extend_ref1 = object::generate_extend_ref(&obj_cont);
        let object_signer = object::generate_signer(&obj_cont);
        let objet_cap =Obj_cap{
            del_ref:del_ref1,
            extend_ref:extend_ref1,
            trans_ref:trans_ref1
        };
        move_to(&object_signer,objet_cap );
        move_to(&object_signer,Root_node{
            entry_number:0,
            children:smart_vector::new<Leaf_node>()
        });
    }

    // Generate second layer of non-leaf node
    // You can set Max_Level to control the max layer number
    fun init_step_2(caller:&signer) acquires Root_node {
        let new_node = Leaf_node{
            is_leaf:1,
            id_start:0,
            id_end:Id_range-1,
            key_word_store:smart_vector::new<Leaf_key>()
        };
        let borrow_root = borrow_global_mut<Root_node>(create_object_address(&create_resource_address(&@aptos_sql,Seed ),Seed));
        smart_vector::push_back(&mut  borrow_root.children,new_node);

    }

    //===================== init fun =========================//
}

module aptos_sql::sql_struct {

    use std::option;
    use std::option::Option;
    use std::string::{String, utf8};
    use std::vector;
    use aptos_std::debug;
    use aptos_std::smart_table;
    use aptos_std::smart_vector;
    use aptos_std::smart_vector::{SmartVector, borrow};
    use aptos_std::table;
    use aptos_std::table_with_length;
    use aptos_std::table_with_length::TableWithLength;
    use aptos_framework::account::{create_resource_account, SignerCapability};
    use aptos_framework::object;
    use aptos_framework::object::{Object, DeleteRef, ExtendRef, TransferRef, create_object_address};
    use aptos_framework::account::create_resource_address;
    use aptos_framework::genesis;


    const Seed :vector<u8> = b"aptos_SQL";

    // Error code
    const E_not_exist_leaf :u64 =1;
    const E_not_exist_leaf_key :u64 =2;
    const E_not_same_obj_store:u64=3;

    // Useful const
    const Max_Level:u64 = 3; // Max layer of node
    const Max_Organ:u64 = 3; // Max leaf key
    const Id_range:u64 = 40; // Leaf node id range
    const Leaf_key_id:u64=50;

    // ============ ability ============ //
    struct Obj_cap has key,store{
        del_ref : Option<DeleteRef>,
        extend_ref:ExtendRef,
        trans_ref : TransferRef,

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
    struct Table_v1 has key ,store,copy,drop{
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
        print_obj()
    }

    //=====================test=========================//

    public fun print_obj ()  {
        // debug::print(&utf8(b"Generate object address"));
        // debug::print(&object::create_object_address(&create_resource_address(&@aptos_sql,Seed ),Seed));
        // debug::print(&utf8(b"object leaf node"));
        // debug::print(&object::address_to_object<Root_node>(object::create_object_address(&create_resource_address(&@aptos_sql,Seed ),Seed)));
        //debug::print(&utf8(b"root leaf node"));
        //debug::print(borrow_global<Root_node>(object::create_object_address(&create_resource_address(&@aptos_sql,Seed ),Seed)));

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
    //===================== logic fun =========================//

    fun find_leaf_id(leaf_key:&Leaf_key,name:String){


        // leaf_key.key_word
    }
    fun find_leaf_own_name(input:String,name:String):bool{
        input == name
    }
    fun find_leaf_node(vector_leaf_node:&SmartVector<Leaf_node>,now_leaf:u64):u64{
        let i=0;
        let length=smart_vector::length(vector_leaf_node);
        while(i < length){
            let specfic =smart_vector::borrow(vector_leaf_node,i);
            if(specfic.id_end > now_leaf){
              return i
            };
            i = i +1;
        };
        return 00000000000
    }
    // find key word of leaf key
    fun find_leaf_Key(vector_leaf_key:&SmartVector<Leaf_key>,name:&String):u64{
        let i=0;
        let length=smart_vector::length(vector_leaf_key);
        while(i < length){
            let specfic =smart_vector::borrow(vector_leaf_key,i);
            let j=0;
            let second_length =smart_vector::length(&specfic.key_word);
            while (j < second_length){
                let borrow_string = borrow(&specfic.key_word,j);
                if(borrow_string == name){
                    return i
                };
                j=j+1;
            };
            i = i +1;
        };
        return 00000000000
    }
    fun return_table_v1(name:String,x1:u64,y1:u64,pointer_id:Option<u64>):Table_v1{
        Table_v1{
            table_name:name,
            x:x1,
            y:y1,
            ponter_v2_id:pointer_id
        }
    }
    fun return_table_v1_from_table_v2(table_v1:&mut Option<Table_v1>):Table_v1{
        let while_v1 =Table_v1{
            table_name:utf8(b""),
            x:0,
            y:0,
            ponter_v2_id:option::none<u64>()
        };
        let real_table_v1 = option::swap( table_v1,while_v1);
        let return_table_v1 = return_table_v1(real_table_v1.table_name,real_table_v1.x,real_table_v1.y,real_table_v1.ponter_v2_id);
        option::swap( table_v1,real_table_v1);
        return_table_v1
    }
    fun return_table_data(data_address:&Object<Object_store>,x:u64,y:u64,option1:Option<u64>):vector<String> acquires Object_store {
        let new_vector = vector::empty<String>();
        let continue_loop =true;
        let borrow=borrow_global_mut<Object_store>(object::object_address(data_address));
        // inital check  table_v1 from x, y  start
        let table_v1_first_time = return_table_v1(borrow.key_word, x, y, option1);
        assert!(table_v1_first_time.table_name == borrow.key_word, E_not_same_obj_store);
        // find inital table_v2
        let table_v1 = return_table_v1_from_table_v2(&mut option::some(table_v1_first_time));
        let table_v2 = smart_table::borrow_mut(&mut borrow.store,table_v1);
        // push first table_v2.store to new_vector
        vector::push_back(&mut new_vector, table_v2.store);
        while(continue_loop){
            if (!option::is_none(&table_v2.pointer_y)) {
                // according table_v2.pointer_y to find next table_v1
                let next_table_v1 = return_table_v1_from_table_v2(&mut table_v2.pointer_y);
                let next_table_v2 = smart_table::borrow_mut(&mut borrow.store, next_table_v1);

                // push next table_v2.store
                vector::push_back(&mut new_vector, next_table_v2.store);

                // updata table_v2  to be next one
                table_v2 = next_table_v2;
            } else {
                // if no next table_v1 , end loop
                continue_loop = false;
            }
        };
        new_vector
    }

    //===================== logic fun =========================//
    //===================== public struct fun =========================//
    public fun search_all_node_without_information(name:String) acquires Root_node, Object_store {
        let now_leaf_id= 0;
        let a =&borrow_global<Root_node>(object::create_object_address(&create_resource_address(&@aptos_sql,Seed),Seed)).children;
        let leaf_next = find_leaf_node(a,now_leaf_id);
        assert!(leaf_next != 00000000000,E_not_exist_leaf);
        let leaf_node = smart_vector::borrow(a,leaf_next);
        let leaf_key_index = find_leaf_Key(&leaf_node.key_word_store,&name);
        assert!(leaf_key_index != 00000000000,E_not_exist_leaf_key);
        let leaf_key = smart_vector::borrow(&leaf_node.key_word_store,leaf_key_index);
        return_table_data(&leaf_key.key_address,0,0,option::some((1 as u64)));

    }
    //===================== public struct fun =========================//
}

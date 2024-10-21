module aptos_sql::sql_struct {

    use std::option;
    use std::option::Option;
    use std::signer::address_of;
    use std::string;
    use std::string::{String, utf8};
    use std::vector;
    use aptos_std::debug;
    use aptos_std::smart_table;
    use aptos_std::smart_table::SmartTable;
    use aptos_std::smart_vector;
    use aptos_std::smart_vector::{SmartVector, borrow};
    use aptos_std::table;
    use aptos_std::table_with_length;
    use aptos_std::table_with_length::TableWithLength;
    use aptos_framework::account::{create_resource_account, SignerCapability, create_signer_with_capability};
    use aptos_framework::object;
    use aptos_framework::object::{Object, DeleteRef, ExtendRef, TransferRef, create_object_address};
    use aptos_framework::account::create_resource_address;
    use aptos_framework::genesis;
    use aptos_sql::data_owner::create_object_store_proof;
    #[test_only]
    use aptos_sql::data_owner::call_collection_init;


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
    const Table_colume_number:u64=100;

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
    // |==========================================||=======================================| // |================last one==================| //
    // |("Excel 1",10,1,11 ), (10,"c",v1 -> (1,2))||("Excel 1",10,2,21),(20,"f",v1 ->(1,3))| // |("Excel 1",10,10,none),(20,"f",v1 ->(1,3))| //
    // |==========================================||=======================================| // |=======================================| //
    struct Table_v2 has key ,store,copy{
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
        length_of_table:u64,
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
        now_leaf:u64,
        id_end:u64,
        key_word_store:smart_vector::SmartVector<Leaf_key>
    }
    // Root entry of all
    struct Root_node has key{
        entry_number:u64,
        leaf_number:u64,
        children:SmartVector<Leaf_node>
    }
    //init for aptos sql
    fun init_module(caller:&signer) acquires Root_node {
        init_step_1(caller);
        init_step_2(caller)
    }



    //=====================test=========================//

    #[test_only]
    public fun call_init(caller:&signer) acquires Root_node {
        init_module(caller);
    }

    #[test(caller=@aptos_sql)]
    fun test_init(caller:&signer) acquires Root_node {
        init_module(caller);
        print_obj()
    }

    //=====================test=========================//



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
            leaf_number:1,
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
            now_leaf:0,
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
    fun find_leaf_Key(vector_leaf_key:&SmartVector<Leaf_key>,name:&String):Option<u64>{
        let i=0;
        let length=smart_vector::length(vector_leaf_key);
        while(i < length){
            let specfic =smart_vector::borrow(vector_leaf_key,i);
            let j=0;
            let second_length =smart_vector::length(&specfic.key_word);
            while (j < second_length){
                let borrow_string = borrow(&specfic.key_word,j);
                if(borrow_string == name){
                    return option::some(i)
                };
                j=j+1;
            };
            i = i +1;
        };
        return  option::none()
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
    //add data from i index
    fun add_table_data_from_i(data_vector:&vector<String>,smart_table1:&mut SmartTable<Table_v1,Table_v2>,table_name1:String,start_index:u64){
        let x_index = start_index/Table_colume_number;
        let y_index = start_index%Table_colume_number;
        if(x_index == 0){
            x_index = 1;
        };
        let table_v1_1= Table_v1{
            table_name:table_name1,
            x:x_index,
            y:y_index,
            ponter_v2_id:option::some(start_index)
        };
        if( smart_table::contains(smart_table1,table_v1_1)){
            let next_table_v2 = smart_table::borrow_mut(smart_table1,table_v1_1);
            let table_v2_index = next_table_v2.table_id;
            if(option::is_none(&next_table_v2.pointer_y)){
                y_index+1;
                let next_table_v1 = Table_v1 {
                    table_name: table_name1,
                    x: x_index,
                    y: y_index ,
                    ponter_v2_id: option::some(start_index + 1),
                };
                next_table_v2.pointer_y = option::some(next_table_v1);
                let i = 0;
                let length = vector::length(data_vector);
                while (i < length){
                    let borrow_string = vector::borrow(data_vector,i);

                    let new_next_table_v1 = Table_v1{
                        table_name:table_name1,
                        x:x_index,
                        y:y_index,
                        ponter_v2_id:option::some(table_v2_index+1)
                    };
                    if(start_index+i %Table_colume_number == 0){
                        x_index=x_index+1;
                        y_index=0;
                    }else{
                        y_index= y_index+1;
                    };
                    let next_next_table_v1=Table_v1{
                        table_name:table_name1,
                        x:x_index,
                        y:y_index,
                        ponter_v2_id:option::some(table_v2_index+2)
                    };
                    let new_next_table_v2 = Table_v2{
                        table_id:table_v2_index,
                        store:*borrow_string,
                        pointer_y:option::some(next_next_table_v1)
                    };
                    smart_table::add(smart_table1,new_next_table_v1, new_next_table_v2);
                    table_v2_index=table_v2_index+1;
                    i=i+1;
                }
            }
        }
    }

    // from 0 add data for empty table
    fun add_table_date (data_vector:&vector<String>,smart_table1:&mut SmartTable<Table_v1,Table_v2>,table_name1:String){
        let i =0;
        let x_index= 1;
        let y_index = 1;
        let pointer_index = 1;
        let length = vector::length(data_vector);
        if(length != 0){
              while(i < length){
                  let spesific =vector::borrow(data_vector,i);
                  if(i+1 == length){
                      let new_table_v1 = Table_v1{
                          table_name:table_name1,
                          x:x_index,
                          y:y_index,
                          ponter_v2_id:option::some(pointer_index)
                      };
                      let  new_table_v2 = Table_v2{
                          table_id:pointer_index,
                          store:*spesific,
                          pointer_y:option::none<Table_v1>()
                      };
                      smart_table::add(smart_table1,new_table_v1,new_table_v2);
                  }else{
                      let new_table_v1 = Table_v1{
                          table_name:table_name1,
                          x:x_index,
                          y:y_index,
                          ponter_v2_id:option::some(pointer_index)
                      };

                      if(y_index % Table_colume_number == 0){
                          y_index=1;
                          x_index=x_index+1;
                          let next_table_v1 = Table_v1{
                              table_name:table_name1,
                              x:x_index,
                              y:y_index,
                              ponter_v2_id:option::some(pointer_index+1)
                          };
                          let  new_table_v2 = Table_v2{
                              table_id:pointer_index,
                              store:*spesific,
                              pointer_y:option::some(next_table_v1)
                          };
                          smart_table::add(smart_table1,new_table_v1,new_table_v2);
                      }else{
                          let next_table_v1 = Table_v1{
                              table_name:table_name1,
                              x:x_index ,
                              y:y_index+ 1 ,
                              ponter_v2_id:option::some(pointer_index+1)
                          };
                          let  new_table_v2 = Table_v2{
                              table_id:pointer_index,
                              store:*spesific,
                              pointer_y:option::some(next_table_v1)
                          };
                          y_index=y_index+1;
                          smart_table::add(smart_table1,new_table_v1,new_table_v2);
                      };
                  };
                  i=i+1;
                  pointer_index = pointer_index + 1;
              }
        };
    }
    fun insert_data_have_table_name(){

    }

    //===================== logic fun =========================//
    //===================== public struct fun =========================//
    public fun search_all_node_without_information(name:String): vector<String> acquires Root_node, Object_store {
        // use for "SELECT * FROM <table_name>"
        // return all data under that table
        let result_vector = vector::empty<String>();
        // Initialize now_leaf_id, or get it from Root_node based on actual logic
        let root = borrow_global<Root_node>(object::create_object_address(&create_resource_address(&@aptos_sql, Seed), Seed));
        let leaf_nodes = &root.children;
        let  i = 0;
        // Traverse all leaf nodes
        let length = smart_vector::length(leaf_nodes);
        while (i < length) {
            let leaf_node = smart_vector::borrow(leaf_nodes, i);

            // Find matching leaf_key for the name
            let leaf_key_index = find_leaf_Key(&leaf_node.key_word_store, &name);
            assert!(!option::is_none(&leaf_key_index), E_not_exist_leaf_key);

            // If found, retrieve the corresponding leaf_key and data
            let leaf_key = smart_vector::borrow(&leaf_node.key_word_store, option::destroy_some(leaf_key_index));
            let return_vector_1 = return_table_data(&leaf_key.key_address, 0, 0, option::some((1 as u64)));
            // Append found data to the result vector
            vector::append(&mut result_vector, return_vector_1);
            i = i + 1;
        };
        result_vector
    }
    public fun insert_new_table_struct(caller:&signer,table_name1:String,new_data:vector<String>) acquires Root_node, Resouces_cap, Object_store {
        let root = borrow_global_mut<Root_node>(object::create_object_address(&create_resource_address(&@aptos_sql,Seed),Seed));
        root.entry_number+1;
        let new_smart_vector_key_word = smart_vector::empty<String>();
        let resource_signer = &create_signer_with_capability(&borrow_global<Resouces_cap>(create_resource_address(&@aptos_sql,Seed)).cap);
        smart_vector::push_back(&mut new_smart_vector_key_word,table_name1);
        if(root.leaf_number == 1){

            let borrow_leaf = smart_vector::borrow_mut(&mut root.children,0);
            if(borrow_leaf.now_leaf == 0){
                let new_object = object::create_object(address_of(resource_signer));
                let new_object_extend = object::generate_extend_ref(&new_object);
                let new_object_transref = object::generate_transfer_ref(&new_object);
                let new_object_delref = object::generate_delete_ref(&new_object);
                object::disable_ungated_transfer(&new_object_transref);
                let new_object_cap = Obj_cap{
                    del_ref:option::some(new_object_delref),
                    extend_ref:new_object_extend,
                    trans_ref:new_object_transref
                };
                move_to(&object::generate_signer(&new_object),new_object_cap);
                let new_table = smart_table::new<Table_v1,Table_v2>();
                add_table_date(&new_data,&mut new_table,table_name1);
                let new_object_store = Object_store{
                    is_leaf:1,
                    own_leaf_id:1,
                    next_leaf:option::none<address>(),
                    obj_store_id:1,
                    next_obj_store_id:2,
                    key_word:table_name1,
                    length_of_table:smart_vector::length(&new_smart_vector_key_word),
                    store:new_table
                };
                move_to(&object::generate_signer(&new_object), new_object_store);
                let object_store = object::object_from_constructor_ref<Object_store>(&new_object);
                let new_leaf_key = Leaf_key{
                    id:1,
                    key_word:new_smart_vector_key_word,
                    key_address:object_store
                };
                smart_vector::push_back(&mut borrow_leaf.key_word_store,new_leaf_key);

            }else {
               let key = find_leaf_Key(&borrow_leaf.key_word_store,&table_name1);
                if(!option::is_none(&key)){
                    let specific_leaf_key = smart_vector::borrow_mut(&mut borrow_leaf.key_word_store,option::destroy_some(key));
                    let obj_address = object::object_address(&specific_leaf_key.key_address);
                    let borrow_object_data = borrow_global_mut<Object_store>(obj_address);
                    if(object::is_owner(specific_leaf_key.key_address,address_of(caller))){
                        let x_index = borrow_object_data.length_of_table/Table_colume_number;
                        let y_index = borrow_object_data.length_of_table%Table_colume_number;
                        if(x_index == 0){
                            x_index = 1;
                        };
                        let table_v1_1= Table_v1{
                            table_name:table_name1,
                            x:x_index,
                            y:y_index,
                            ponter_v2_id:option::some( borrow_object_data.length_of_table)
                        };
                       if( smart_table::contains(&borrow_object_data.store,table_v1_1)){
                          let next_table_v2 = smart_table::borrow_mut(&mut borrow_object_data.store,table_v1_1);
                           if(option::is_none(&next_table_v2.pointer_y)){

                           }
                       }
                    };
                    //delete after test
                    let cons =object::create_object(address_of(caller));
                    move_to(&object::generate_signer(&cons),Object_store{
                        is_leaf:0,
                        own_leaf_id:0,
                        next_leaf:option::none<address>(),
                        obj_store_id:0,
                        next_obj_store_id:0,
                        key_word:utf8(b""),
                        length_of_table:0,
                        store:smart_table::new<Table_v1,Table_v2>()
                    });
                    move_to(caller,Leaf_key{
                        id:0,
                        key_word:new_smart_vector_key_word,
                        key_address:object::object_from_constructor_ref<Object_store>(&cons)
                    });
                    //delete after test
                }else{
                    //delete after test
                    let cons =object::create_object(address_of(caller));
                    move_to(&object::generate_signer(&cons),Object_store{
                        is_leaf:0,
                        own_leaf_id:0,
                        next_leaf:option::none<address>(),
                        obj_store_id:0,
                        next_obj_store_id:0,
                        key_word:utf8(b""),
                        length_of_table:0,
                        store:smart_table::new<Table_v1,Table_v2>()
                    });
                    move_to(caller,Leaf_key{
                        id:0,
                        key_word:new_smart_vector_key_word,
                        key_address:object::object_from_constructor_ref<Object_store>(&cons)
                    });
                    //delete after test
                }
            };
            create_object_store_proof(resource_signer,caller,table_name1,1)
        }else{
            let i=0;
            let length_leaf_key = smart_vector::length(&root.children);
            while (i < length_leaf_key){
                let specific_leaf_node = smart_vector::borrow_mut(&mut root.children,i);
                let key = find_leaf_Key(&specific_leaf_node.key_word_store,&table_name1);
                if(option::is_none(&key)){
                    //none states
                }else{
                    // have this table
                };
                i=i+1;
            };
            //delete after test
            let cons =object::create_object(address_of(caller));
            move_to(&object::generate_signer(&cons),Object_store{
                is_leaf:0,
                own_leaf_id:0,
                next_leaf:option::none<address>(),
                obj_store_id:0,
                next_obj_store_id:0,
                key_word:utf8(b""),
                length_of_table:0,
                store:smart_table::new<Table_v1,Table_v2>()
            });
            move_to(caller,Leaf_key{
                id:0,
                key_word:new_smart_vector_key_word,
                key_address:object::object_from_constructor_ref<Object_store>(&cons)
            });
            //delete after test

            create_object_store_proof(resource_signer,caller,table_name1,1)
        };




         //create_object_store_proof(caller,table_name1,object_store_id1:u64)  // create key nft to owner
    }
    //===================== public struct fun =========================//

    #[test_only]
    public fun struct_call_collision_init() acquires Resouces_cap {
        let resource_signer = &create_signer_with_capability(&borrow_global<Resouces_cap>(create_resource_address(&@aptos_sql,Seed)).cap);
        call_collection_init(resource_signer);
    }

    //===================== print fun =========================//

    public fun print_root_tree() acquires Root_node {
        debug::print(&utf8(b"root struct"));
        debug::print(borrow_global_mut<Root_node>(object::create_object_address(&create_resource_address(&@aptos_sql,Seed),Seed)));
    }
    public fun print_object_store() acquires Root_node, Object_store {
        debug::print(&utf8(b"object store struct"));
        debug::print(borrow_global<Object_store>(object::object_address(&smart_vector::borrow(&smart_vector::borrow(&borrow_global_mut<Root_node>(object::create_object_address(&create_resource_address(&@aptos_sql,Seed),Seed)).children,0).key_word_store,0).key_address)));
    }
    public fun print_table_data_all_key() acquires Root_node, Object_store {
        debug::print(&utf8(b"table data struct 1"));
        debug::print(vector::borrow(&smart_table::keys(&borrow_global<Object_store>(object::object_address(&smart_vector::borrow(&smart_vector::borrow(&borrow_global_mut<Root_node>(object::create_object_address(&create_resource_address(&@aptos_sql,Seed),Seed)).children,0).key_word_store,0).key_address)).store),0));
        debug::print(&utf8(b"table data struct 2"));
        debug::print(vector::borrow(&smart_table::keys(&borrow_global<Object_store>(object::object_address(&smart_vector::borrow(&smart_vector::borrow(&borrow_global_mut<Root_node>(object::create_object_address(&create_resource_address(&@aptos_sql,Seed),Seed)).children,0).key_word_store,0).key_address)).store),1));
        debug::print(&utf8(b"table data struct 3"));
        debug::print(vector::borrow(&smart_table::keys(&borrow_global<Object_store>(object::object_address(&smart_vector::borrow(&smart_vector::borrow(&borrow_global_mut<Root_node>(object::create_object_address(&create_resource_address(&@aptos_sql,Seed),Seed)).children,0).key_word_store,0).key_address)).store),2));
        debug::print(&utf8(b"table data struct 4"));
        debug::print(vector::borrow(&smart_table::keys(&borrow_global<Object_store>(object::object_address(&smart_vector::borrow(&smart_vector::borrow(&borrow_global_mut<Root_node>(object::create_object_address(&create_resource_address(&@aptos_sql,Seed),Seed)).children,0).key_word_store,0).key_address)).store),3));
        debug::print(&utf8(b"table data struct 5"));
        debug::print(vector::borrow(&smart_table::keys(&borrow_global<Object_store>(object::object_address(&smart_vector::borrow(&smart_vector::borrow(&borrow_global_mut<Root_node>(object::create_object_address(&create_resource_address(&@aptos_sql,Seed),Seed)).children,0).key_word_store,0).key_address)).store),4));
    }
    public fun print_table_data_table_v2() acquires Root_node, Object_store {

        debug::print(&utf8(b"table data table_v2 1"));
        debug::print(smart_table::borrow(&borrow_global<Object_store>(object::object_address(&smart_vector::borrow(&smart_vector::borrow(&borrow_global_mut<Root_node>(object::create_object_address(&create_resource_address(&@aptos_sql,Seed),Seed)).children,0).key_word_store,0).key_address)).store,*vector::borrow(&smart_table::keys(&borrow_global<Object_store>(object::object_address(&smart_vector::borrow(&smart_vector::borrow(&borrow_global_mut<Root_node>(object::create_object_address(&create_resource_address(&@aptos_sql,Seed),Seed)).children,0).key_word_store,0).key_address)).store),0)));
        debug::print(&utf8(b"table data table_v2 2"));
        debug::print(smart_table::borrow(&borrow_global<Object_store>(object::object_address(&smart_vector::borrow(&smart_vector::borrow(&borrow_global_mut<Root_node>(object::create_object_address(&create_resource_address(&@aptos_sql,Seed),Seed)).children,0).key_word_store,0).key_address)).store,*vector::borrow(&smart_table::keys(&borrow_global<Object_store>(object::object_address(&smart_vector::borrow(&smart_vector::borrow(&borrow_global_mut<Root_node>(object::create_object_address(&create_resource_address(&@aptos_sql,Seed),Seed)).children,0).key_word_store,0).key_address)).store),1)));
        debug::print(&utf8(b"table data table_v2 3"));
        debug::print(smart_table::borrow(&borrow_global<Object_store>(object::object_address(&smart_vector::borrow(&smart_vector::borrow(&borrow_global_mut<Root_node>(object::create_object_address(&create_resource_address(&@aptos_sql,Seed),Seed)).children,0).key_word_store,0).key_address)).store,*vector::borrow(&smart_table::keys(&borrow_global<Object_store>(object::object_address(&smart_vector::borrow(&smart_vector::borrow(&borrow_global_mut<Root_node>(object::create_object_address(&create_resource_address(&@aptos_sql,Seed),Seed)).children,0).key_word_store,0).key_address)).store),2)));
        debug::print(&utf8(b"table data table_v2 4"));
        debug::print(smart_table::borrow(&borrow_global<Object_store>(object::object_address(&smart_vector::borrow(&smart_vector::borrow(&borrow_global_mut<Root_node>(object::create_object_address(&create_resource_address(&@aptos_sql,Seed),Seed)).children,0).key_word_store,0).key_address)).store,*vector::borrow(&smart_table::keys(&borrow_global<Object_store>(object::object_address(&smart_vector::borrow(&smart_vector::borrow(&borrow_global_mut<Root_node>(object::create_object_address(&create_resource_address(&@aptos_sql,Seed),Seed)).children,0).key_word_store,0).key_address)).store),3)));
        debug::print(&utf8(b"table data table_v2 5"));
        debug::print(smart_table::borrow(&borrow_global<Object_store>(object::object_address(&smart_vector::borrow(&smart_vector::borrow(&borrow_global_mut<Root_node>(object::create_object_address(&create_resource_address(&@aptos_sql,Seed),Seed)).children,0).key_word_store,0).key_address)).store,*vector::borrow(&smart_table::keys(&borrow_global<Object_store>(object::object_address(&smart_vector::borrow(&smart_vector::borrow(&borrow_global_mut<Root_node>(object::create_object_address(&create_resource_address(&@aptos_sql,Seed),Seed)).children,0).key_word_store,0).key_address)).store),4)));
    }
    public fun print_obj ()  {
        // debug::print(&utf8(b"Generate object address"));
        // debug::print(&object::create_object_address(&create_resource_address(&@aptos_sql,Seed ),Seed));
        // debug::print(&utf8(b"object leaf node"));
        // debug::print(&object::address_to_object<Root_node>(object::create_object_address(&create_resource_address(&@aptos_sql,Seed ),Seed)));
        //debug::print(&utf8(b"root leaf node"));
        //debug::print(borrow_global<Root_node>(object::create_object_address(&create_resource_address(&@aptos_sql,Seed ),Seed)));

    }
    //===================== print fun =========================//
}

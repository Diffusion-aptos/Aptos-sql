module aptos_sql::data_owner {

    use std::option;
    use std::option::Option;
    use std::signer;
    use std::string::{String, utf8};
    use aptos_framework::account::{SignerCapability, create_resource_address, create_signer_with_capability};
    use aptos_framework::event::emit;
    use aptos_token_objects::token;
    use aptos_framework::object;
    use aptos_framework::object::{TransferRef,ExtendRef, DeleteRef};
    use aptos_token_objects::royalty::Royalty;
    use aptos_token_objects::token::{MutatorRef, BurnRef};

    const Seed :vector<u8> = b"aptos_SQL";
    const Aptos_sql_collection:vector<u8> =b"Aptos sql key";
    const Aptos_sql_describe : vector<u8> =b"Key to locate where your data store";
    const Aptos_sql_collection_url : vector<u8> =b"";
    const Aptos_sql_token_describe : vector<u8> =b"This is an key for owner to control his data !";
    const Aptos_sql_token_url : vector<u8> =b"";

    struct Resouces_cap has key {
        cap:SignerCapability
    }
    struct Owner_table has key,store {
        owner:address,
        key_word_name:String,
        object_store_id:u64,
        object_store_Address:address,
        ability:Control_cap
    }
    struct Control_cap has key,store {
        transfer_cap:TransferRef,
        extend_cap:ExtendRef,
        del_cap:Option<DeleteRef>
    }
    struct Token_control has key,store {
        muta_ref:MutatorRef,
        burn_ref:BurnRef
    }
    #[event]
    struct Import_new_table has key,drop,copy,store{
        caller_address:address,
        key_word:String,
        object_store_id:u64,
        generate_key_address:address
    }

    fun create_object_store_proof(caller:&signer,key_word1:String,object_store_id1:u64) acquires Resouces_cap {
        let resoucres_signer = &create_signer_with_capability(
            &borrow_global<Resouces_cap>(create_resource_address(&@aptos_sql, Seed)).cap
        );
        let token_conf =token::create_numbered_token(resoucres_signer,utf8(Aptos_sql_collection),utf8(Aptos_sql_token_describe),utf8(b"Aptos SQL key #"),utf8(b""),option::none<Royalty>(),utf8(Aptos_sql_token_url));
        let token_mutf = token::generate_mutator_ref(&token_conf);
        let token_burnf = token::generate_burn_ref(&token_conf);
        let token_signer = &object::generate_signer(&token_conf);
        let new_owner_table = Owner_table{
            owner:signer::address_of(caller),
            key_word_name:key_word1,
            object_store_id:object_store_id1,
            object_store_Address:object::address_from_constructor_ref(&token_conf),
            ability:Control_cap{
                transfer_cap:object::generate_transfer_ref(&token_conf),
                extend_cap:object::generate_extend_ref(&token_conf),
                del_cap:option::none<DeleteRef>()
            }
        };
        emit(Import_new_table{
            caller_address:signer::address_of(caller),
            key_word:key_word1,
            object_store_id:object_store_id1,
            generate_key_address:object::address_from_constructor_ref(&token_conf)
        });
        move_to(token_signer,new_owner_table);
        move_to(token_signer,Token_control{
            muta_ref:token_mutf,
            burn_ref:token_burnf
        });

    }
    fun collection_init(caller:&signer) acquires Resouces_cap {
        let resoucres_signer = &create_signer_with_capability(
            &borrow_global<Resouces_cap>(create_resource_address(&@aptos_sql, Seed)).cap
        );
        let collection_consfer = &aptos_token_objects::collection::create_unlimited_collection(resoucres_signer,utf8(Aptos_sql_describe),utf8(Aptos_sql_collection),option::none<Royalty>(),utf8(Aptos_sql_collection_url));
        let exten_ref = object::generate_extend_ref(collection_consfer);
        let del_ref = option::none<DeleteRef>();
        let tran_ref = object::generate_transfer_ref(collection_consfer);
        let new_control = Control_cap{
            transfer_cap:tran_ref,
            del_cap:del_ref,
            extend_cap:exten_ref
        };
        move_to(&object::generate_signer( collection_consfer),new_control);
    }
}

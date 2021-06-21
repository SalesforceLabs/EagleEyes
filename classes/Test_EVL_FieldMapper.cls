@isTest
public class Test_EVL_FieldMapper {

    static testmethod void  testEVL_FieldMapper(){
    Test.StartTest();
        String FieldName='search_query';
        system.assertEquals(EVL_FieldMapper.canConvertName(FieldName),true);
        system.assertEquals(EVL_FieldMapper.getConvertedName(FieldName),'query');

    Test.stopTest();
        
        
    }
}
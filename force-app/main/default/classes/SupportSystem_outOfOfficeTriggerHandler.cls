/*
 *****************************************************************************************************************************
 Apex Class Name    : SupportSystem_outOfOfficeTriggerHandler comment by me for testing
 @description       : This class contains methods used to process custom OOO & Chatter OOO records,Add delegate user as caseTeam for L2
 and also handles Add/Remove case Team functionality for RMA
 author             : Microchip Support System - Service Cloud
 *****************************************************************************************************************************
 */
public without sharing class SupportSystem_outOfOfficeTriggerHandler{
    /*
     ***********************************************************************************************************************
     @Method Name                : processOutOfOffice
     @description                : This method is used to process OOO record after the start time,handle chatter OOO if OOO is created/owned by the same user for themselves,
     add delegate user as case team member for L2 cases and post OOO message as a private comment for L2
     @param newOutOfOfficeList     : List of new version custom OutOfOffice records
     @param outOfOfficeOldMap    : old version Map of custom OOO record Ids and OOO records
     @return                     : void
     ***********************************************************************************************************************
     */
    public static void processOutOfOffice(list<Out_Of_Office__c> newOutOfOfficeList, map<Id, Out_Of_Office__c> outOfOfficeOldMap){
        try{
            list<Out_Of_Office__c> oooToProcess = new List<Out_Of_Office__c>();
            set<Id> delegatedUserIds = new set<Id>();
            set<Id> currentUserIds = new set<Id>();
            map<Id, Id> mapOoOUserWithDelegatedUser = new map<Id, Id>();
            map<Id, List<Case>> mapUserIdWithCases = new map<Id, List<Case>>();
            for (Out_Of_Office__c ooo : newOutOfOfficeList){
                if (!String.isBlank(ooo.User__c) && ooo.Active__c && ooo.Process_Out_Of_Office__c && outOfOfficeOldMap.get(ooo.Id).Process_Out_Of_Office__c == false){
                    if (ooo.Process_Chatter_OOO__c){
                        oooToProcess.add(ooo);
                    }
                    currentUserIds.add(ooo.User__c);
                    if (!String.isBlank(ooo.Delegated_User__c)){
                        delegatedUserIds.add(ooo.Delegated_User__c);
                        mapOoOUserWithDelegatedUser.put(ooo.User__c, ooo.Delegated_User__c);
                    }
                }
            }
            if (!oooToProcess.isEmpty()){
                handleChatterOutOfOffice(oooToProcess);
            }
            //optimized System.debug('currentUserIds===>' + currentUserIds);

            if (!currentUserIds.isEmpty()){
                //Added logic to process chatter out of office by user

                mapUserIdWithCases = getCasesToProcess(currentUserIds);

                System.debug('mapUserIdWithCases===>' + mapUserIdWithCases);
                /* optimized if (mapUserIdWithCases != null && !mapUserIdWithCases.values().isEmpty()){
                 System.debug('mapUserIdWithCases.getValues().size()===>' + mapUserIdWithCases.values().size());
                 }*/
                if (mapUserIdWithCases != null && !mapUserIdWithCases.keySet().isEmpty()){
                    boolean isValidCaseTeam = false;
                    map<Id, User> mapDelegatedUserIdWithEmail = new map<Id, User>();
                    if (delegatedUserIds != null && delegatedUserIds.size() > 0){
                        for (User usr : [SELECT Id, Name, Email
                                         FROM User
                                         Where Id IN:delegatedUserIds]){
                            mapDelegatedUserIdWithEmail.put(usr.Id, usr);
                        }
                    }
                    set<String> teamMemberAlreadyExists = new set<String>();
                    set<String> memberIds = new set<String>();
                    map<Id, List<String>> mapCaseIdWithEmailsAddedToCaseTeam = new map<Id, List<String>>();
                    list<CaseTeamMember> lstCaseTeamMembersToInsert = new list<CaseTeamMember>();
                    List<CaseComment__c> lstCaseCommentsToInsert = new List<CaseComment__c>();
                    mapCaseIdWithEmailsAddedToCaseTeam = getExistingCaseTeamOfCases(mapUserIdWithCases);
                    System.debug('mapCaseIdWithEmailsAddedToCaseTeam===>' + mapCaseIdWithEmailsAddedToCaseTeam);
                    //Add delegated user to Case Team
                    // optimized not used map<Id, map<String, User>> mapToSendEmailtoCaseTeam = new map<Id, map<String, User>>();
                    String teamRoleId = '';
                    List<CaseTeamRoleInfo__mdt> teamRolesList = CaseTeamRoleInfo__mdt.getAll().values();
                    for (CaseTeamRoleInfo__mdt teamRoleInfo : teamRolesList){
                        if (teamRoleInfo.DeveloperName == 'Read_Write'){
                            teamRoleId = teamRoleInfo.TeamRoleId__c;
                            break;
                        }
                    }
                    for (Out_Of_Office__c ooo : newOutOfOfficeList){
                        if (!String.isBlank(ooo.User__c) && ooo.Active__c && ooo.Process_Out_Of_Office__c && outOfOfficeOldMap.get(ooo.Id).Process_Out_Of_Office__c == false){
                            if (mapUserIdWithCases != null && mapUserIdWithCases.get(ooo.User__c) != null){

                                for (Case cas : mapUserIdWithCases.get(ooo.User__c)){
                                    if (mapCaseIdWithEmailsAddedToCaseTeam.get(cas.Id) != null && !String.isBlank(ooo.Delegated_User__c)){
                                        if (!mapCaseIdWithEmailsAddedToCaseTeam.get(cas.Id).contains(mapDelegatedUserIdWithEmail.get(ooo.Delegated_User__c).Email)){
                                            //Add case team
                                            isValidCaseTeam = true;
                                            /* optimized CaseTeamMember teamMember = new CaseTeamMember(
                                             ParentId = cas.Id,
                                             MemberId = ooo.Delegated_User__c,
                                             TeamRoleId = teamRoleId
                                             );
                                             lstCaseTeamMembersToInsert.add(teamMember);
                                             map<String, User> mapOldEmailsAddedUsers = new map<String, User>();
                                             mapOldEmailsAddedUsers.put(mapDelegatedUserIdWithEmail.get(ooo.Delegated_User__c).Email, mapDelegatedUserIdWithEmail.get(ooo.Delegated_User__c));*/

                                            // optimized not used mapToSendEmailtoCaseTeam.put(cas.Id, mapOldEmailsAddedUsers);
                                        }
                                    } else{
                                        if (!String.isBlank(ooo.Delegated_User__c)){
                                            //Add case team
                                            isValidCaseTeam = true;
                                            /* optimized CaseTeamMember teamMember = new CaseTeamMember(
                                             ParentId = cas.Id,
                                             MemberId = ooo.Delegated_User__c,
                                             TeamRoleId = teamRoleId
                                             );
                                             lstCaseTeamMembersToInsert.add(teamMember);
                                             map<String, User> mapOldEmailsAddedUsers = new map<String, User>();
                                             mapOldEmailsAddedUsers.put(mapDelegatedUserIdWithEmail.get(ooo.Delegated_User__c).Email, mapDelegatedUserIdWithEmail.get(ooo.Delegated_User__c));*/

                                            // optimized not used mapToSendEmailtoCaseTeam.put(cas.Id, mapOldEmailsAddedUsers);
                                        }

                                    }
                                    if (isValidCaseTeam){

                                        CaseTeamMember teamMember = new CaseTeamMember(
                                            ParentId = cas.Id, 
                                            MemberId = ooo.Delegated_User__c, 
                                            TeamRoleId = teamRoleId
                                        );
                                        lstCaseTeamMembersToInsert.add(teamMember);
                                        map<String, User> mapOldEmailsAddedUsers = new map<String, User>();
                                        mapOldEmailsAddedUsers.put(mapDelegatedUserIdWithEmail.get(ooo.Delegated_User__c).Email, mapDelegatedUserIdWithEmail.get(ooo.Delegated_User__c));
                                        isValidCaseTeam = false; //reset to false
                                    }
                                }
                                System.debug('lstCaseTeamMembersToInsert====>' + lstCaseTeamMembersToInsert);

                                //Insert Case Comments
                                for (Case cas : mapUserIdWithCases.get(ooo.User__c)){
                                    CaseComment__c comment = new CaseComment__c();
                                    comment.ParentId__c = cas.Id;
                                    String caseOwnerName = cas.Owner.Name;
                                    // optimized not used String caseOwnerEmail = cas.Owner.Email;
                                    if (!String.isBlank(ooo.Delegated_User__c)){
                                        String detegatedUserName = mapDelegatedUserIdWithEmail.get(mapOoOUserWithDelegatedUser.get(cas.OwnerId)).Name;
                                        // optimized not used String detegatedUserEmail = mapDelegatedUserIdWithEmail.get(mapOoOUserWithDelegatedUser.get(cas.OwnerId)).Email;
                                        comment.CommentBody__c = 'Case Owner ' + caseOwnerName + ' is Out of Office : ' + ooo.Start_Date_Time__c.format('MMM d HH:mm a') + ' - ' + ooo.End_Date_Time__c.format('MMM d HH:mm a') + '. If you need help during this time, please reach out to ' + detegatedUserName + '.';
                                    } else{
                                        comment.CommentBody__c = 'Case Owner ' + caseOwnerName + ' is Out of Office : ' + ooo.Start_Date_Time__c.format('MMM d HH:mm a') + ' - ' + ooo.End_Date_Time__c.format('MMM d HH:mm a') + '.';
                                    }

                                    if (cas.RecordType.Name == 'L2 Case' || cas.RecordType.Name == 'FA Request'){
                                        comment.isPublished__c = false;
                                    }
                                    lstCaseCommentsToInsert.add(comment);
                                }

                            }
                        }
                    }
                    if (!lstCaseTeamMembersToInsert.isEmpty()){
                        insert lstCaseTeamMembersToInsert;
                        /* optimized for (Id caseId : mapToSendEmailtoCaseTeam.keySet()){
                         map<String, Contact> mapOldEmailsAddedContacts = new map<String, Contact>();
                         //SupportSystem_UtilityClass.sendEmailNotificationToCaseTeam(mapToSendEmailtoCaseTeam.get(caseId),mapOldEmailsAddedContacts,String.valueOf(caseId),'Added','L2 Case');
                         }*/
                    }
                    if (!lstCaseCommentsToInsert.isEmpty()){
                        Database.executeBatch(new SupportSystem_InsertSobjectsBatch(lstCaseCommentsToInsert), 1);
                    }
                }
            }
        } catch (exception e){
            System.debug('e.getMessage()===>' + e.getMessage());
        }
    }

    /*
     ***********************************************************************************************************************
     @Method Name            : getCasesToProcess
     @description            : This method is used to fetch list of L2 cases owned by the OOO user
     @param currentUserIds     : OOO user Ids
     @return                 : Map of OOO user Id with List of cases
     ***********************************************************************************************************************
     */
    public static map<Id, List<Case>> getCasesToProcess(set<Id> currentUserIds){
        map<Id, List<Case>> mapIdWithCases = new map<Id, List<Case>>();
        if (!currentUserIds.isEmpty()){
            for (Case cas : [SELECT Id, OwnerId, Owner.Name, Owner.Email, RecordTypeId, RecordType.Name
                             FROM Case
                             WHERE OwnerId IN:currentUserIds AND Status != 'Closed - Resolved' AND Status != 'Closed - No Response']){
                if (cas.RecordType.Name == 'L2 Case'){
                    if (mapIdWithCases != null && mapIdWithCases.get(cas.OwnerId) != null){
                        list<Case> lstCases = new list<Case>();
                        lstCases = mapIdWithCases.get(cas.OwnerId);
                        lstCases.add(cas);
                        mapIdWithCases.put(cas.OwnerId, lstCases);
                    } else{
                        list<Case> lstCases = new list<Case>();
                        lstCases.add(cas);
                        mapIdWithCases.put(cas.OwnerId, lstCases);
                    }
                }
            }
        }

        return mapIdWithCases;
    }

    /*
     ***********************************************************************************************************************
     @Method Name            : getExistingCaseTeamOfCases
     @description            : This method is used to fetch existing case team members related to the case record
     @param mapCases         : Map of OOO user Id and their assigned list of cases
     @return                 : Map of case record Id and existing case Team emails 
     ***********************************************************************************************************************
     */
    public static map<Id, List<String>> getExistingCaseTeamOfCases(map<Id, List<Case>> mapCases){
        map<Id, List<String>> mapCaseIdWithCaseTeam = new map<Id, List<String>>();
        set<Id> caseIds = new set<Id>();
        for (Id userId : mapCases.keySet()){
            for (Case cas : mapCases.get(userId)){
                caseIds.add(cas.Id);
            }
        }
        if (!caseIds.isEmpty()){
            set<Id> memberIds = new set<Id>();
            map<Id, String> mapMemberIdWithEmail = new map<Id, String>();
            map<Id, List<String>> mapCaseIdWithTeamMembers = new map<Id, List<String>>();
            for (CaseTeamMember member : [SELECT Id, ParentId, MemberId
                                          FROM CaseTeamMember
                                          WHERE ParentId IN:caseIds]){
                memberIds.add(member.MemberId);
                if (mapCaseIdWithTeamMembers != null && mapCaseIdWithTeamMembers.get(member.ParentId) != null){
                    List<String> existingmems = new List<String>();
                    existingmems = mapCaseIdWithTeamMembers.get(member.ParentId);
                    existingmems.add(member.MemberId);
                    mapCaseIdWithTeamMembers.put(member.ParentId, existingmems);
                } else{
                    List<String> newMems = new List<String>();
                    newMems.add(member.MemberId);
                    mapCaseIdWithTeamMembers.put(member.ParentId, newMems);
                }
            }
            // optimized System.debug('mapCaseIdWithTeamMembers===>' + mapCaseIdWithTeamMembers);
            // optimized System.debug('memberIds===>' + memberIds);
            if (!memberIds.isEmpty()){
                set<Id> userIds = new set<Id>();
                set<Id> conIds = new set<Id>();
                for (Id memId : memberIds){
                    if (!String.isBlank(memId)){
                        if (String.valueOf(memId).startsWith('005')){
                            userIds.add(memId);
                        }
                        if (String.valueOf(memId).startsWith('003')){
                            conIds.add(memId);
                        }
                    }
                }
                for (User usr : [SELECT Id, Email
                                 FROM User
                                 WHERE Id IN:userIds]){
                    mapMemberIdWithEmail.put(usr.Id, usr.Email);
                }
                for (Contact con : [SELECT Id, Email
                                    FROM Contact
                                    WHERE Id IN:conIds]){
                    mapMemberIdWithEmail.put(con.Id, con.Email);
                }
                System.debug('userIds===>' + userIds);
                System.debug('conIds===>' + conIds);
                System.debug('mapMemberIdWithEmail===>' + mapMemberIdWithEmail);

                for (Id caseId : caseIds){
                    if (mapCaseIdWithTeamMembers != null && mapCaseIdWithTeamMembers.get(caseId) != null){
                        List<String> caseTeamEmails = new List<String>();
                        for (String teamMem : mapCaseIdWithTeamMembers.get(caseId)){
                            if (mapMemberIdWithEmail != null && mapMemberIdWithEmail.get(teamMem) != null){
                                //caseTeamEmails = mapMemberIdWithEmail.get(teamMem);
                                caseTeamEmails.add(mapMemberIdWithEmail.get(teamMem));
                            }
                        }
                        mapCaseIdWithCaseTeam.put(caseId, caseTeamEmails);
                    } else{
                        mapCaseIdWithCaseTeam.put(caseId, null);
                    }
                }
            }
        }
        system.debug('mapCaseIdWithCaseTeam===>' + mapCaseIdWithCaseTeam);
        return mapCaseIdWithCaseTeam;
    }

    /*
     ***********************************************************************************************************************
     @Method Name            : handleChatterOutOfOffice
     @description            : This method is used to insert or update Chatter OOO records
     @param lstOoO           : List of Custom OOO records
     @return                 : void
     ***********************************************************************************************************************
     */
    public static void handleChatterOutOfOffice(List<Out_Of_Office__c> lstOoO){
        set<Id> currentUserIds = new set<Id>();
        map<Id, Out_Of_Office__c> mapUserIdWithCustomOoO = new map<Id, Out_Of_Office__c>();
        for (Out_Of_Office__c ooo : lstOoO){
            if (!String.isBlank(ooo.User__c) && ooo.Active__c && ooo.Process_Out_Of_Office__c){
                currentUserIds.add(ooo.User__c);
                mapUserIdWithCustomOoO.put(ooo.User__c, ooo);
            }
        }
        if (!currentUserIds.isEmpty()){
            map<Id, OutOfOffice> mapUserIdWithOoO = new map<Id, OutOfOffice>();
            List<OutOfOffice> lstOoOToInsert = new List<OutOfOffice>();
            List<OutOfOffice> lstOoOToUpdate = new List<OutOfOffice>();
            for (OutOfOffice ooo : [SELECT Id, UserId, StartDate, EndDate, Message, isEnabled
                                    FROM OutofOffice
                                    WHERE UserId IN:currentUserIds AND isEnabled = true
                                    Order By CreatedDate DESC]){
                if (mapUserIdWithOoO != null && mapUserIdWithOoO.get(ooo.UserId) == null){
                    mapUserIdWithOoO.put(ooo.UserId, ooo);
                }
            }
            for (Out_Of_Office__c ooo : lstOoO){
                if (!String.isBlank(ooo.User__c) && ooo.Active__c && ooo.Process_Out_Of_Office__c){
                    if (mapUserIdWithOoO != null && mapUserIdWithOoO.get(ooo.User__c) != null){
                        OutOfOffice oooRcrd = mapUserIdWithOoO.get(ooo.User__c);
                        if (oooRcrd.EndDate < ooo.End_Date_Time__c){
                            oooRcrd.EndDate = ooo.End_Date_Time__c;
                            oooRcrd.StartDate = ooo.Start_Date_Time__c;
                            /*if(oooRcrd.StartDate < ooo.Start_Date_Time__c && oooRcrd.EndDate < ooo.Start_Date_Time__c){
                             oooRcrd.StartDate = ooo.Start_Date_Time__c;
                             }*/
                            oooRcrd.Message = 'Out of Office: ' + ooo.Start_Date_Time__c.format('MMM d') + ' - ' + ooo.End_Date_Time__c.format('MMM d');
                            lstOoOToUpdate.add(oooRcrd);
                        } else if (oooRcrd.EndDate > ooo.End_Date_Time__c){
                            if (oooRcrd.StartDate > ooo.Start_Date_Time__c){
                                oooRcrd.StartDate = ooo.Start_Date_Time__c;
                                oooRcrd.Message = 'Out of Office: ' + ooo.Start_Date_Time__c.format('MMM d') + ' - ' + ooo.End_Date_Time__c.format('MMM d');
                                lstOoOToUpdate.add(oooRcrd);
                            }
                        }
                    } else{
                        OutOfOffice oooRcrd = new OutOfOffice();
                        oooRcrd.EndDate = ooo.End_Date_Time__c;
                        oooRcrd.StartDate = ooo.Start_Date_Time__c;
                        oooRcrd.UserId = ooo.User__c;
                        oooRcrd.Message = 'Out of Office: ' + ooo.Start_Date_Time__c.format('MMM d') + ' - ' + ooo.End_Date_Time__c.format('MMM d');
                        oooRcrd.isEnabled = true;
                        lstOoOToInsert.add(oooRcrd);
                    }

                }
            }
            if (!lstOoOToInsert.isEmpty()){
                insert lstOoOToInsert;
            }
            if (!lstOoOToUpdate.isEmpty()){
                update lstOoOToUpdate;
            }
        }
    }

    /*
     ***********************************************************************************************************************
     @Method Name                    : handleUpdateOfOoO
     @description                    : This method is used to handle update of Custom OOO & Chatter OOO records
     @param newOutOfOfficeList         : List of New version of Custom OOO records
     @param outOfOfficeOldMap         : Map of previous version of Custom OOO record Id & OOO record
     @return                         : void
     ***********************************************************************************************************************
     */
    public static void handleUpdateOfOoO(list<Out_Of_Office__c> newOutOfOfficeList, map<Id, Out_Of_Office__c> outOfOfficeOldMap){
        List<Out_Of_Office__c> setChatterOoO = new List<Out_Of_Office__c>();
        /*for(Out_Of_Office__c ooo : newOutOfOfficeList){
         if(ooo.Ative__c){
         setChatterOoO.add(ooo);
         }
         }
         if(!setChatterOoO.isEmpty()){
         //handleChatterOutOfOffice(setChatterOoO);
         }*/
        set<Id> userIds = new set<Id>();
        map<Id, Out_Of_Office__c> mapUserWithCustomOoO = new map<Id, Out_Of_Office__c>();
        for (Out_Of_Office__c ooo : newOutOfOfficeList){
            if (outOfOfficeOldMap != null){
                if (outOfOfficeOldMap.get(ooo.Id) != null){
                    if ((ooo.Active__c != outOfOfficeOldMap.get(ooo.Id).Active__c && ooo.Active__c == false) || ((ooo.End_Date_Time__c != outOfOfficeOldMap.get(ooo.Id).End_Date_Time__c || ooo.Start_Date_Time__c != outOfOfficeOldMap.get(ooo.Id).Start_Date_Time__c) && ooo.Active__c == true)){
                        userIds.add(ooo.User__c);
                        mapUserWithCustomOoO.put(ooo.User__c, ooo);
                    }
                }
            } else{
                userIds.add(ooo.User__c);
                mapUserWithCustomOoO.put(ooo.User__c, ooo);
            }
        }
        if (!userIds.isEmpty()){
            map<Id, OutOfOffice> mapUserWithOoO = new map<Id, OutOfOffice>();
            List<OutOfOffice> lstChatterOoOToUpdate = new List<OutOfOffice>();
            List<OutOfOffice> lstChatterOoOToInsert = new List<OutOfOffice>();
            for (OutOfOffice ooo : [SELECT Id, UserId, StartDate, EndDate, Message, isEnabled
                                    FROM OutofOffice
                                    WHERE UserId IN:userIds AND isEnabled = true
                                    Order By CreatedDate DESC]){
                if (mapUserWithOoO != null && mapUserWithOoO.get(ooo.UserId) == null){
                    mapUserWithOoO.put(ooo.UserId, ooo);
                }
            }
            if (mapUserWithCustomOoO != null && !mapUserWithCustomOoO.keySet().isEmpty()){
                for (Id userId : mapUserWithCustomOoO.keySet()){
                    OutOfOffice oooRcrd = new OutOfOffice();
                    Out_Of_Office__c customOoO = new Out_Of_Office__c();
                    customOoO = mapUserWithCustomOoO.get(userId);
                    if (mapUserWithOoO != null && mapUserWithOoO.get(userId) != null){
                        oooRcrd = mapUserWithOoO.get(userId);
                        if (customOoO.End_Date_Time__c <= DateTime.now() || customOoO.Active__c == false){
                            oooRcrd.isEnabled = false;
                            lstChatterOoOToUpdate.add(oooRcrd);
                        } else if (customOoO.End_Date_Time__c > DateTime.now() && customOoO.Active__c == true){
                            oooRcrd.EndDate = customOoO.End_Date_Time__c;
                            oooRcrd.StartDate = customOoO.Start_Date_Time__c;
                            oooRcrd.Message = 'Out of Office: ' + customOoO.Start_Date_Time__c.format('MMM d') + ' - ' + customOoO.End_Date_Time__c.format('MMM d');
                            lstChatterOoOToUpdate.add(oooRcrd);
                        }
                    } else{
                        oooRcrd.EndDate = customOoO.End_Date_Time__c;
                        oooRcrd.StartDate = customOoO.Start_Date_Time__c;
                        oooRcrd.UserId = customOoO.User__c;
                        oooRcrd.Message = 'Out of Office: ' + customOoO.Start_Date_Time__c.format('MMM d') + ' - ' + customOoO.End_Date_Time__c.format('MMM d');
                        oooRcrd.isEnabled = true;
                        lstChatterOoOToInsert.add(oooRcrd);
                    }
                }
            }
            if (!lstChatterOoOToUpdate.isEmpty()){
                update lstChatterOoOToUpdate;
            }
            if (!lstChatterOoOToInsert.isEmpty()){
                insert lstChatterOoOToInsert;
            }
        }

        publishPlatformEvent(newOutOfOfficeList);
    }

    /*
     **********************************************************************************************************************************************
     @Method Name                    : publishPlatformEvent
     @description                    : This platform event is used to handle OOO Create and Edit events in SupportSystem_OutOfOffice lightning component
     @param newOutOfOfficeList         : List of New version of Custom OOO records
     @param outOfOfficeOldMap         : Map of previous version of Custom OOO record Id & OOO record
     @return                         : void
     **********************************************************************************************************************************************
     */
    public static void publishPlatformEvent(list<Out_Of_Office__c> newOutOfOfficeList){

        Support_System_Platform_Event__e event = new Support_System_Platform_Event__e(
            Message__c = 'success', 
            Event__c = 'Record Updated', 
            sObjectName__c = 'Out_Of_Office__c'
        );
        Database.SaveResult result = EventBus.publish(event);
        if (!result.isSuccess()){
            for (Database.Error error : result.getErrors()){
                System.debug('Error returned: ' + error.getStatusCode() + ' - ' + error.getMessage());
            }
        }
    }

    /*
     ***********************************************************************************************************************
     @Method Name                    : setProcessChatterOOO
     @description                    : This method is used to set Process_Chatter_OOO__c field to true or false based on whether the OOO record
     is created by the same user (or) Admin (or) by different user
     @param newOutOfOfficeList         : List of New version of Custom OOO records
     @return                         : void
     ***********************************************************************************************************************
     */
    public static void setProcessChatterOOO(list<Out_Of_Office__c> newOutOfOfficeList){
        Profile adminProfile = [Select id, name
                                from profile
                                where name = 'System Administrator'];
        String adminProfileId = adminProfile.id;
        for (Out_Of_Office__c ooo : newOutOfOfficeList){
            if (UserInfo.getuserId().equals(ooo.user__c) || UserInfo.getProfileId().equals(adminProfileId)){
                ooo.Process_Chatter_OOO__c = true;
            } else{
                ooo.Process_Chatter_OOO__c = false;
            }
        }
    }

    /*
     ***********************************************************************************************************************
     @Method Name                    : addOrRemoveCaseTeamForRMA
     @description                    : This method is used to add or remove case Team members in RMA cases based on the status of OOO records
     @param ctOOOList                 : List of Custom OOO records
     @param removeUser                 : boolean to indicate whether case team members need to be removed
     @return                         : void
     ***********************************************************************************************************************
     */
    //SALESFORCE-841
    public static void addOrRemoveCaseTeamForRMA(List<Out_Of_Office__c> ctOOOList, Boolean removeUser){
        
        //CaseTeam Audit Code - Start
		Map<String,Set<String>> caseTeamAuditToUpdateAdded = new Map<String,Set<String>>();
		Set<String> memberIdsForCaseTeamAuditAdded = new Set<String>();
        Map<String,Set<String>> caseTeamAuditToUpdateRemoved = new Map<String,Set<String>>();
		Set<String> memberIdsForCaseTeamAuditAddedRemoved = new Set<String>();
		//CaseTeam Audit Code - End
        
        //Get the RMA Line record type Id
        String rmaRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('RMA Line').getRecordTypeId();
        //Map to store the OOO user and their respective Delegated user
        Map<Id, Id> userWithDelegates = new Map<Id, Id>();
        //Map to store the case id and the respective case team members
        Map<Id, List<CaseTeamMember>> caseWithCTMembers = new Map<Id, List<CaseTeamMember>>();
        List<CaseTeamMember> toBeAddedCTM = new List<CaseTeamMember>();
        List<CaseTeamMember> toBeremovedCTM = new List<CaseTeamMember>();
        Map<Id, Case> rmaCases = new Map<Id, Case>();
        Map<Id, Boolean> deleteCaseTeamMap = new Map<Id, Boolean>();
        String supportProcessID = system.label.SupportSystem_SupportProcessUserId;

        //List to store all the allowed status values
        Set<String> statusValues = new Set<String>{ 'New', 'In Progress', 'Awaiting Customer Response', 'Awaiting MCHP Internal Feedback', 'RMA Issued', 'Re-Opened', 'Quoted', 'Assigned' };
        //Store Case Team roles
        Map<String, Id> roleMap = SupportSystem_TriggerMonitor.roleMap;

        for (Out_Of_Office__c ooo : ctOOOList){
            userWithDelegates.put(OOO.User__c, OOO.Delegated_User__c);
            //By default, set the deleteCaseTeamMap value to true for the current user. It will be changed to false, if any active OOO present with same delegated user, else it will remain as true.
            deleteCaseTeamMap.put(OOO.User__c, true);
        }
        
        if (removeUser){
            statusValues.addAll(new set<String>{ 'Closed - Resolved', 'Closed - No Response', 'Cancelled' });
            //SALESFORCE-1045 - Start
            Map<Id, List<Out_Of_Office__c>> usersActiveOOO = new Map<Id, List<Out_Of_Office__c>>();
            List<Out_Of_Office__c> activeOOOs = [SELECT Id, Start_Date_Time__c, End_Date_Time__c, Active__c, User__c, Delegated_User__c
                                                 FROM Out_Of_Office__c
                                                 WHERE User__c = :userWithDelegates.keySet() AND Active__c = true];
            if (!activeOOOs.isEmpty()){
                for (Out_Of_Office__c ooo : activeOOOs){
                    if (usersActiveOOO.containsKey(ooo.User__c)){
                        usersActiveOOO.get(ooo.User__c).add(ooo);
                    } else{
                        usersActiveOOO.put(ooo.User__c, new List<Out_Of_Office__c>());
                        usersActiveOOO.get(ooo.User__c).add(ooo);
                    }
                }
                
                for (Out_Of_Office__c currentOOO : ctOOOList){               
                    //Fetch all the active OOO of the given OOO user
                    for (Out_Of_Office__c activeOOO : usersActiveOOO.get(currentOOO.User__c)){
                        //Check if the current OOO's end time lies between any of the other active OOO
                        if (currentOOO.End_Date_Time__c > activeOOO.Start_Date_Time__c && currentOOO.End_Date_Time__c < activeOOO.End_Date_Time__c){
                            //Check if the current OOO's delegated user is same as the active OOO's delegated user
                            //If the condition is satisfied, put 'false' in the deleteCaseTeamMap and break the inside for loop
                            if (currentOOO.Delegated_User__c == activeOOO.Delegated_User__c){
                                deleteCaseTeamMap.put(currentOOO.User__c, false);
                                break;
                            }
                        }
                    }
                }
            }
            //SALESFORCE-1045 - End
        }
        rmaCases = new Map<Id, Case>([SELECT Id, OwnerId, Increase_Control__c
                                      FROM Case
                                      WHERE RecordTypeId = :rmaRecordTypeId AND OwnerId = :userWithDelegates.keySet() AND Status IN:statusValues]);
        //Get all the case team members of the RMA line cases
        for (CaseTeamMember ct : [SELECT Id, ParentId, MemberId, CreatedById
                                  FROM CaseTeamMember
                                  WHERE ParentId = :rmaCases.keySet()]){
            if (!caseWithCTMembers.containsKey(ct.ParentId)){
                caseWithCTMembers.put(ct.ParentId, new List<CaseTeamMember>());
                caseWithCTMembers.get(ct.ParentId).add(ct);
            } else if (caseWithCTMembers.containsKey(ct.ParentId)){
                caseWithCTMembers.get(ct.ParentId).add(ct);
            }
        }
        //Loop over all the RMA line cases and add the delegate user in the case team
        for (Case c : rmaCases.values()){
            Boolean addDelegateToCT = true;

            Id delegateUser = userWithDelegates.get(c.OwnerId);
            List<CaseTeamMember> ctList = new List<CaseTeamMember>();

            if (caseWithCTMembers.containsKey(c.Id)){
                ctList.addAll(caseWithCTMembers.get(c.Id));
            }
            //If there are case team members present, check whether the delegate user is already present.
            if (ctList.size() > 0 && ctList != null){
                for (CaseTeamMember ct : ctList){
                    if (!removeUser && addDelegateToCT){
                        if (ct.MemberId == delegateUser){
                            addDelegateToCT = false;
                            break;
                        }
                    }
                    //If removeUser is true and the value of deleteCaseTeamMap for the given user is true, then we need to remove the delegated user
                    if (removeUser && deleteCaseTeamMap.get(c.OwnerId)){
                        if (ct.MemberId == delegateUser && ct.CreatedById == supportProcessID){
                            //If the delegate is present, add the id to the list to be deleted.
                            toBeremovedCTM.add(ct);
                            
                            //CaseTeam Audit Code - Start
                            memberIdsForCaseTeamAuditAddedRemoved.add(ct.MemberId);
                            caseTeamAuditToUpdateRemoved.put(ct.ParentId,memberIdsForCaseTeamAuditAddedRemoved);
                            //CaseTeam Audit Code - End
                            
                            addDelegateToCT = false;
                            break;
                        }
                    }
                }
            }
            if (addDelegateToCT && !removeUser){
                CaseTeamMember ctm = new CaseTeamMember();
                ctm.ParentId = c.Id;
                ctm.MemberId = delegateUser;
                
                //CaseTeam Audit Code - Start
                memberIdsForCaseTeamAuditAdded.add(ctm.MemberId);
                caseTeamAuditToUpdateAdded.put(ctm.ParentId,memberIdsForCaseTeamAuditAdded);
                //CaseTeam Audit Code - End
                
                //If the case has increase control requested, the team role should not be Read/Write.
                if (c.Increase_Control__c == 'Requested'){
                    ctm.TeamRoleId = roleMap.get('No Communication Internal Controlled Case');
                } else{
                    ctm.TeamRoleId = roleMap.get('Read/Write');
                }
                toBeAddedCTM.add(ctm);
            }
        }
        if (toBeAddedCTM.size() > 0){
            Database.insert (toBeAddedCTM, false);
            //CaseTeam Audit Code - Start
            if(!caseTeamAuditToUpdateAdded.isEmpty()){
                SupportSystem_CaseTeamAudit.handleCaseTeamAuditRecord(caseTeamAuditToUpdateAdded, 'Added');
            }
            //CaseTeam Audit Code - End
        }

        if (toBeremovedCTM.size() > 0){
            Database.delete (toBeremovedCTM, false);
            //CaseTeam Audit Code - Start
            if(!caseTeamAuditToUpdateRemoved.isEmpty()){
                SupportSystem_CaseTeamAudit.handleCaseTeamAuditRecord(caseTeamAuditToUpdateRemoved, 'Removed');
            }
            //CaseTeam Audit Code - End
        }
    }
    
    /*
     ********************************************************************************************************************************************************
     @Method Name                    : delegatedUserCheck
     @description                    : This method is used to check whether Delegate user is present in the OOO record if the OOO user owns any open RMA line cases
     @param newOutOfOfficeList         : List of Custom OOO records
     @return                         : void
     ********************************************************************************************************************************************************
     */
    //SALESFORCE-928 - Start
    public static void delegatedUserCheck(List<Out_Of_Office__c> oooList){
        //Store the OOO users' ids in a set
        Set<Id> oooUsers = new Set<Id>();
        //Set to store the owner ids who owne open RMA line cases.
        Set<Id> ownerIds = new Set<Id>();
        //Get the RMA Line record type Id
        String rmaRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('RMA Line').getRecordTypeId();
        //List to store all the allowed status values
        Set<String> statusValues = new Set<String>{ 'New', 'In Progress', 'Awaiting Customer Response', 'Awaiting MCHP Internal Feedback', 'RMA Issued', 'Re-Opened', 'Quoted', 'Assigned' };

        for (Out_Of_Office__c ooo : oooList){
            oooUsers.add(ooo.User__c);
        }

        //Group the cases based on ownerId to reduce the elements in the for loop.
        for (AggregateResult rmaCase : [SELECT OwnerId
                                        FROM Case
                                        WHERE RecordTypeId = :rmaRecordTypeId AND OwnerId = :oooUsers AND Status IN:statusValues
                                        GROUP By OwnerId]){
            //Store the ownerIds who own open RMA line cases in a set.
            ownerIds.add(String.valueOf(rmaCase.get('OwnerId')));
        }

        for (Out_Of_Office__c ooo : oooList){
            //If the ownerIds set contains the OOO user and the delegated user is blank, then throw an error.
            if (ownerIds.contains(ooo.User__c) && String.isBlank(ooo.Delegated_User__c) && ooo.Active__c == true){
                ooo.Delegated_User__c.addError('Delegated user is mandatory if the OoO user owns open RMA line case(s).');
            }
        }
    }
    //SALESFORCE-928 - End
    //SALESFORCE-1044 - Start
    /*
     ***********************************************************************************************************************
     @Method Name                    : disableEditAfterStartTime
     @description                    : This method is used to disable edit option in OOO record once start time is reached
     @param oooList                  : List of Custom OOO records
     @param oooOldMap                : Map of previous version of Custom OOO record Id & OOO record
     @return                         : void
     ***********************************************************************************************************************
     */
    public static void disableEditAfterStartTime(List<Out_Of_Office__c> oooList, Map<Id, Out_Of_Office__c> oooOldMap){
        for (Out_Of_Office__c ooo : oooList){
            if (oooOldMap.get(ooo.Id).Start_Date_Time__c <= system.now()){
                //If OOO is started and delegated user is changed, throw an error.
                if (ooo.Delegated_User__c != oooOldMap.get(ooo.Id).Delegated_User__c){
                    ooo.Delegated_User__c.addError(System.Label.SupportSystem_OOO_Trigger_Error_DelegatedUser);
                }
                //If ooo is started and start/end time or user value is changed, throw an error
                else if (oooOldMap.get(ooo.Id).Start_Date_Time__c != ooo.Start_Date_Time__c || oooOldMap.get(ooo.Id).End_Date_Time__c != ooo.End_Date_Time__c || oooOldMap.get(ooo.Id).User__c != ooo.User__c){
                    if(ooo.Allow_Update__c == false){
                        ooo.addError(System.Label.SupportSystem_OOO_Trigger_Error);
                    }
                    ooo.Allow_Update__c = false;
                }
            }
        }
    }

    /*
     *************************************************************************************************************************************************
     @Method Name                    : startTimeValidation
     @description                    : This method is used to throw an error if the start date time is less than current date time.
     Once the OOO is started we are allowing users to modify the end date using 'Extend' option. So this method should be called only in before insert
     If the OOO is started, the start time will be less than current time, so calling this method in before update will not allow users to use extend
     functionality. i.e, if we call this method in before update, it will always throw an validation error.
     @param                          : List of new OOO records
     @return                         : void
     *************************************************************************************************************************************************
     */
    public static void startTimeValidation(List<Out_Of_Office__c> oooList){
        for (Out_Of_Office__c ooo : oooList){
            if (ooo.Start_Date_Time__c < system.now()){
                ooo.Start_Date_Time__c.addError('The start date time cannot be less than the current date time');
            }
        }
    }  
    //SALESFORCE-1044 - End
}
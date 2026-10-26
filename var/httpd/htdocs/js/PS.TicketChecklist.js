// --
// PS.TicketChecklist.js - provides the special module functions for the time tracking add on
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file COPYING for license information (AGPL). If you
// did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var PS = PS || {};

var ToggleState = 0;

/**
 * @namespace
 * @exports TargetNS as PS.TicketChecklist
 * @description
 *      This namespace contains the special module functions for the time tracking add on
 */
PS.TicketChecklist = (function (TargetNS) {

    $('#ClearBtn').bind( 'click', function() {
        $('#ChecklistItems').children().remove();

        return false;
    });

    $('#ToggleAllBtn').bind( 'click', ToggleAllDiv );

    function ToggleAllDiv() {
        if ( ToggleState ) {
            $('span[id^="InfoMore_"]').removeClass( 'fa-eye-slash' ).addClass( 'fa-eye' );
            $('div[id^="Info_"]').addClass('Hidden');
            ToggleState = 0;
        }
        else {
            $('span[id^="InfoMore_"]').removeClass( 'fa-eye' ).addClass( 'fa-eye-slash' );
            $('div[id^="Info_"]').removeClass('Hidden');
            ToggleState = 1;
            Core.UI.InputFields.InitSelect($('select[name*="Priority"]'));
            Core.UI.InputFields.InitSelect($('select[name*="Responsible"]'));
        }

        return false;
    }

    function ToggleMoreDiv() {
        var ID = $(this).attr('id').replace( 'InfoMore_', '' );

        var MoreDiv = $('#Info_' + ID);
        if ( $(this).hasClass('fa-eye-slash') ) {
            $(this).removeClass('fa-eye-slash');
            $(this).addClass('fa-eye');
            MoreDiv.addClass('Hidden');
        }
        else {
            $(this).addClass('fa-eye-slash');
            $(this).removeClass('fa-eye');
            MoreDiv.removeClass('Hidden');
            Core.UI.InputFields.InitSelect($('select[name*="Priority"]'));
            Core.UI.InputFields.InitSelect($('select[name*="Responsible"]'));
        }

    }

    var BaseURL = window.location.href.replace( window.location.search, "" );

    function NewFromTemplate() {
        var URL = Core.Config.Get('Baselink') || BaseURL;
        var ID  = $(this).val();

        if ( !ID ) {
            return;
        }

        // show spinning wheel
        $('#TemplateLoader').addClass('AJAXLoader');

        var FormData = {
            Action: 'AgentTicketChecklist',
            Subaction: 'NewFromTemplate',
            TicketID: $('#TicketID').val(),
            Position: Positions,
            TemplateID: ID
        };

        if ( !Core.Config.Get('SessionIDCookie') ) {
            var SessionID = Core.Config.Get('SessionID');
            FormData[Core.Config.Get('SessionName')] = SessionID;
            FormData[Core.Config.Get('CustomerPanelSessionName')] = SessionID;
        }

        $.ajax({
            type: 'POST',
            url: URL,
            dataType: 'json',
            data : FormData,
            success: function(response) {
                if ( response.Error ) {
                    console.log( 'Error: ' + response.Error );
                    return;
                }

                var PositionStart = Positions;
                Positions = response.Positions;

                $('span[id^="Arrow"]').unbind( 'click' );
                $('button[name="DelBtn"]').unbind('click' );
                $('span[id^="InfoMore_"]').unbind('click' );

                if ( response.KeepEntries && response.KeepEntries == "1" ) {
                    $('#ChecklistItems').append( response.HTML );
                }
                else {
                    $('#ChecklistItems').html( response.HTML );
                }

                $('span[id^="Arrow"]').bind( 'click', MoveItem );
                BindDelBtn();
                $('span[id^="InfoMore_"]').bind('click', ToggleMoreDiv);

                // hide spinning wheel
                $('#TemplateLoader').removeClass('AJAXLoader');
                $('#ChecklistTemplate').val('');
                $('#ChecklistTemplateSelected').val('1');

                if ( response.KeepEntries && response.KeepEntries == "1" ) {
                    $('#ChecklistTemplateSelected').val('0');
                    $('#ChecklistTemplates').val( $('#ChecklistTemplates').val() + ';' + ID );
                }
                else {
                    $('#ChecklistTemplates').val( ID );
                }

                $('.ResponsibleAutocomplete').each( function() {
                    $(this).unbind( 'change' );
                    var pos = $(this).attr('id').replace( 'ResponsibleSearchField_', '' );
                    TargetNS.AutocompleteInit( $(this), 'ResponsibleSearch', 'Responsible_' + pos );
                });

                for ( var i = PositionStart; i <= Positions; i++ ) {
                    Core.UI.InputFields.InitSelect( $('#ItemStatus_' + i) );

                    var Prefix = 'ItemDueDate_' + i + '_';
                    Core.UI.Datepicker.Init({
                        Day: $("#" + Prefix + "Day"),
                        Month: $("#" + Prefix + "Month"),
                        Year: $("#" + Prefix + "Year"),
                        Hour: $("#" + Prefix + "Hour"),
                        Minute: $("#" + Prefix + "Minute"),
                        VacationDays: Core.Config.Get('Datepicker.VacationDays'),
                        DateInFuture: true,
                        DateNotInFuture: false,
                        WeekDayStart: 1
                    });

                    var PrefixStart = 'ItemDateStart_' + i + '_';
                    Core.UI.Datepicker.Init({
                        Day: $("#" + PrefixStart + "Day"),
                        Month: $("#" + PrefixStart + "Month"),
                        Year: $("#" + PrefixStart + "Year"),
                        Hour: $("#" + PrefixStart + "Hour"),
                        Minute: $("#" + PrefixStart + "Minute"),
                        VacationDays: Core.Config.Get('Datepicker.VacationDays'),
                        DateInFuture: true,
                        DateNotInFuture: false,
                        WeekDayStart: 1
                    });
                }

                Core.UI.InputFields.Activate();
            }
        });
    }

    function NewItem ( TodoItem, ItemPos, CountItems, Sort ) {
        if ( typeof TodoItem === "undefined" ) {
            TodoItem = '';
        }

        if ( typeof ItemPos === "undefined" ) {
            ItemPos = 0;
        }

        var URL = Core.Config.Get('Baselink') || BaseURL;

        var FormData = {
            Action: 'AgentTicketChecklist',
            Subaction: 'NewItem',
            TicketID: $('#TicketID').val(),
            Position: Positions,
            UsePosition: ItemPos,
        };

        if ( !Core.Config.Get('SessionIDCookie') ) {
            var SessionID = Core.Config.Get('SessionID');
            FormData[Core.Config.Get('SessionName')] = SessionID;
            FormData[Core.Config.Get('CustomerPanelSessionName')] = SessionID;
        }

        $.ajax({
            type: 'POST',
            url: URL,
            dataType: 'json',
            data : FormData,
            success: function(response) {
                if ( response.Error ) {
                    console.log( 'Error: ' + response.Error );
                    return;
                }

                var StatusSelect = $('<select name="ItemStatus_' + response.Position + '" id="ItemStatus_' + response.Position + '"> ');
                $.each( response.Status["ItemStatus_" + response.Position], function( Index, Value ) {
                    var Status = new Option( Value[1], Value[0], Value[2], Value[3] );
                    Status.innerHTML = Value[1];
                    StatusSelect.append( Status );
                });

                var UseSlimTheme = Core.Config.Get('UseSlimChecklistTheme');
                var InputClass = 'W50pc';

                if ( UseSlimTheme && UseSlimTheme == 1 ) {
                    InputClass = 'W20pc';
                }

                var TitleInput = $( '<input class="' + InputClass + '" type="text" id="ItemTitle_' + response.Position + '" name="ItemTitle_' + response.Position + '" value="' + TodoItem + '"> ' );
                var DeleteBtn  = $( '<button name="DelBtn" id="DelBtn_' + response.Position + '" class="DelBtn CallForAction" value="-"><span>-</span></button>' );

                var ImagePath   = Core.Config.Get('Images');
                var ArrowUp     = $( '<span id="ArrowUp_' + response.Position + '" class="fa fa-arrow-up" style="cursor: pointer"></span>' );
                var ArrowDown   = $( '<span id="ArrowDown_' + response.Position + '" class="fa fa-arrow-down" style="cursor: pointer"></span>' );

                var MoreText    = Core.Config.Get('more_info_text');
                var MoreInfo    = $( '<span id="InfoMore_' + response.Position + '" class="fa fa-eye" style="cursor: pointer"></span>' );
                var MoreDiv     = $( '<div id="Info_' + response.Position + '" class="Hidden">' );
                var MoreFields  = $( '<fieldset class="TableLike" style="width: 600px">' );

                var ClearDiv    = $( '<div class="Clear"></div>' );

                var CommentLabel    = $( '<label for="Comment">' + Core.Config.Get( 'Comment_text' ) + ': </label>' );
                var CommentTextarea = $( '<textarea name="ItemComment_' + response.Position + '" rows="5" cols="100"></textarea>' );

                var ArticleNumberLabel = $( '<label for="ArticleNumber">' + Core.Config.Get( 'ArticleNumber_text' ) + ': </label>' );
                var ArticleNumberInput = $( '<input type="text" class="W25pc" name="ItemArticleNumber_' + response.Position + '" />' );

                var ResponsibleLabel = $( '<label for="ResponsibleID">' + Core.Config.Get( 'Responsible_text' ) + ': </label>' );
                var ResponsibleSelect = $( '<select name="ItemResponsibleID_' + response.Position + '">' );

                $.each( response.Status["ItemResponsibleID_" + response.Position], function( Index, Value ) {
                    var ResponsibleID = new Option( Value[1], Value[0], Value[2], Value[3] );
                    ResponsibleID.innerHTML = Value[1];
                    ResponsibleSelect.append( ResponsibleID );
                });

                var SearchField;
                if ( Core.Config.Get('PSChecklistUseAutocomplete') && Core.Config.Get('PSChecklistUseAutocomplete') == 1 ) {
                    SearchField     = $('<input type="text" name="ResponsibleSearchField_' + response.Position + '" id="ResponsibleSearchField_' + response.Position + '">');
                    var HiddenField = $('<input type="hidden" name="Responsible_' + response.Position + '" id="Responsible_' + response.Position + '">');

                    ResponsibleSelect = SearchField;
                    ResponsibleSelect.append( HiddenField );
                }

                if ( Core.Config.Get('PSUseDateStartFeature') == 1 ) {
                    var DateStartLabel = $( '<label for="DateStart">' + Core.Config.Get( 'DateStart_text' ) + ': </label>' );
                    var DateStartField = $( '<div class="Field">');
                    DateStartField.append( $.parseHTML( response.DateStart.HTML ) );

                    if ( UseSlimTheme && UseSlimTheme == 1 ) {
                        DateStartField = response.DateStart.HTML;
                    }
                }

                var DueDateLabel = $( '<label for="DueDate">' + Core.Config.Get( 'DueDate_text' ) + ': </label>' );
                var DueDateField = $( '<div class="Field">');
                DueDateField.append( $.parseHTML( response.DueDate.HTML ) );

                if ( UseSlimTheme && UseSlimTheme == 1 ) {
                    DueDateField = response.DueDate.HTML;
                }

                var PriorityLabel = $( '<label for="PriorityID">' + Core.Config.Get( 'Priority_text' ) + ': </label>' );
                var PrioritySelect = $( '<select name="ItemPriorityID_' + response.Position + '">' );

                $.each( response.Status["ItemPriorityID_" + response.Position], function( Index, Value ) {
                    var PriorityID = new Option( Value[1], Value[0], Value[2], Value[3] );
                    PriorityID.innerHTML = Value[1];
                    PrioritySelect.append( PriorityID );
                });

                var ChangeNoteLabel    = $( '<label for="ChangeNote">' + Core.Config.Get( 'ChangeNoteLabel' ) + ': </label> ' );
                var ChangeNoteTextarea = $( '<textarea name="ItemChangeNote_' + response.Position + '" rows="5" cols="100"></textarea> ' );

                MoreFields.append( CommentLabel ).append( $( '<div class="Field">').append( CommentTextarea ) )
                          .append( ArticleNumberLabel ).append( ArticleNumberInput ).append( ClearDiv.clone() );

                if ( !UseSlimTheme || UseSlimTheme != 1 ) {
                    MoreFields.append( ResponsibleLabel ).append( ResponsibleSelect ).append( ClearDiv.clone() );

                    if ( Core.Config.Get('PSUseDateStartFeature') == 1 ) {
                          MoreFields.append( DateStartLabel ).append( DateStartField ).append( ClearDiv.clone() );
                    }

                    MoreFields.append( DueDateLabel ).append( DueDateField ).append( ClearDiv.clone() );
                }

                MoreFields.append( PriorityLabel ).append( PrioritySelect ).append( ClearDiv.clone() )
                          .append( ChangeNoteLabel ).append( ChangeNoteTextarea ).append( ClearDiv.clone() );

                MoreDiv.append( MoreFields ); 

                var ListItem = $('<li id="Item_' + response.Position + '" data-pos="' + response.Position + '">').append(
                    TitleInput
                ).append(
                    StatusSelect
                );

                if ( UseSlimTheme && UseSlimTheme == 1 ) {
                    ListItem.append( ResponsibleSelect );

                    if ( Core.Config.Get('PSUseDateStartFeature') == 1 ) {
                        ListItem.append( DateStartField );
                    }

                    ListItem.append( DueDateField );
                }

                ListItem.append(
                    DeleteBtn
                );

                if ( UseSlimTheme && UseSlimTheme == 1 ) {
                    ListItem.append(
                        '<br />'
                    );
                }

                ListItem.append(
                    ArrowUp
                ).append(
                    ArrowDown
                ).append(
                    MoreInfo
                ).append(
                    MoreDiv
                );

                DeleteBtn.bind('click', function(){ $(this).parent().remove() } );
                ArrowUp.bind('click', MoveItem );
                ArrowDown.bind('click', MoveItem );
                MoreInfo.bind('click', ToggleMoreDiv);

                $('#ChecklistItems').append(
                    ListItem
                );

                Core.UI.InputFields.InitSelect( $('#ItemStatus_' + response.Position)  );
                Core.UI.InputFields.InitSelect($('select[name*="Priority"]'));
                Core.UI.InputFields.InitSelect($('select[name*="Responsible"]'));

                if ( Core.Config.Get('PSChecklistUseAutocomplete') && Core.Config.Get('PSChecklistUseAutocomplete') == 1 ) {
                    TargetNS.AutocompleteInit( SearchField, 'ResponsibleSearch', 'Responsible_' + response.Position );
                }

                var Prefix = 'ItemDueDate_' + response.Position + '_';
                Core.UI.Datepicker.Init({
                    Day: $("#" + Prefix + "Day"),
                    Month: $("#" + Prefix + "Month"),
                    Year: $("#" + Prefix + "Year"),
                    Hour: $("#" + Prefix + "Hour"),
                    Minute: $("#" + Prefix + "Minute"),
                    VacationDays: Core.Config.Get('Datepicker.VacationDays'),
                    DateInFuture: true,
                    DateNotInFuture: false,
                    WeekDayStart: 1
                });

                var PrefixStart = 'ItemDateStart_' + response.Position + '_';
                Core.UI.Datepicker.Init({
                    Day: $("#" + PrefixStart + "Day"),
                    Month: $("#" + PrefixStart + "Month"),
                    Year: $("#" + PrefixStart + "Year"),
                    Hour: $("#" + PrefixStart + "Hour"),
                    Minute: $("#" + PrefixStart + "Minute"),
                    VacationDays: Core.Config.Get('Datepicker.VacationDays'),
                    DateInFuture: true,
                    DateNotInFuture: false,
                    WeekDayStart: 1
                });

                if ( typeof CountItems === "undefined" ) {
                    Positions = response.Position;
                }
                else {
                    Positions = CountItems;
                }

                if ( Sort && Sort == 1 ) {
                    SortItems();
                }
            }
        });
    };

    function SortItems () {
        var Checklist = $('#ChecklistItems');
        var Items     = Checklist.children();

        Items.sort( function ( a, b ) {
            return $(a).data('pos') - $(b).data('pos');
        });

        Checklist.append(Items);
    }

    function DeleteItem ( ItemID ) {
        if ( !Core.Config.Get('HardDeleteItems') || Core.Config.Get('HardDeleteItems') != "1" ) {
            return;
        }

        var URL          = Core.Config.Get('Baselink') || BaseURL;
        var ListTicketID = $('#TicketID').val();

        var FormData = {
            Action: 'AgentTicketChecklist',
            Subaction: 'Delete',
            TicketID: ListTicketID,
            ID: ItemID,
        };

        if ( !Core.Config.Get('SessionIDCookie') ) {
            var SessionID = Core.Config.Get('SessionID');
            FormData[Core.Config.Get('SessionName')] = SessionID;
            FormData[Core.Config.Get('CustomerPanelSessionName')] = SessionID;
        }


        $.ajax({
            type: 'POST',
            url: URL,
            dataType: 'json',
            data : FormData,
        });
    }

    $('#AddBtn').bind( 'click', function() {
        NewItem();
        return false;
    });

    $('#Submit').bind('click', function() {
        var ItemOrder = new Array;

        var Index = 0;
        $('li[id^="Item_"]').each( function() {
            ItemOrder[Index++] = $(this).attr('id').replace('Item_','');
        });

        $('#ItemOrder').val( ItemOrder.join(',') );
    });

    $('#TicketPriorityBtn').on('click', function() {
        var TicketPriority = $('#TicketPriority').val();

        $('select[id^="ItemPriority"]').each( function() {
            $(this).val( TicketPriority );
            $(this).trigger('redraw.InputFields');
        });

        return false;
    });

    function BindDelBtn() {
        $('button[name="DelBtn"]').bind( 'click', function() {
            var Pos       = $(this).attr('id').match( /\d+/ );
            var ID        = $(this).siblings( 'input[id="ItemID_' + Pos[0] + '"]' );

            if ( Core.Config.Get('ConfirmDeleteItems') == "1" ) {
                var DialogTitle = Core.Config.Get( "ConfirmDeleteTitle" )         || "Confirm item deletion";
                var DialogHTML  = Core.Config.Get( "ConfirmDeleteHTML" )          || "Do you want to delete this item?";
                var OkText      = Core.Config.Get( "ConfirmDeleteOkButton" )      || "Ok";
                var CancelText  = Core.Config.Get( "ConfirmDeleteCancelButton" )  || "Cancel";
    
                ShowConfirmDialog( DialogTitle, DialogHTML, OkText, CancelText, $(this), ID );
            }
            else { 
                $(this).parent().remove();
    
                if ( ID ) {
                    DeleteItem( ID.val() );
                }
            }
    
            return false;
        });
    }

    function ShowConfirmDialog( DialogTitle, DialogHTML, OkText, CancelText, ItemElement, ItemID ) {
        Core.UI.Dialog.ShowDialog({
            Modal: true,
            Title: DialogTitle,
            HTML: DialogHTML,
            PositionTop: '100px',
            PositionLeft: 'Center',
            Buttons: [
                {
                    Label: OkText,
                    Function: function() {
                        ItemElement.parent().remove();
        
                        if ( ItemID ) {
                            DeleteItem( ItemID.val() );
                        }

                        Core.UI.Dialog.CloseDialog($('.Dialog:visible'));
                    }
                },
                {
                    Label: CancelText,
                    Function: function() {
                        Core.UI.Dialog.CloseDialog($('.Dialog:visible'));
                    }
                }
            ]
        });
    }

    function MoveItem () {
        var IsUp   = 0;
        if ( $(this).attr('id').match( /Up/ ) ) {
            IsUp   = 1;
        }

        var ItemToMove = $(this).parent();

        if ( IsUp ) {
            ItemToMove.insertBefore( ItemToMove.prev() );
        }
        else {
            ItemToMove.insertAfter( ItemToMove.next() );
        }
    }

    $('span[id^="Arrow"]').bind( 'click', MoveItem );
    $('span[id^="InfoMore"]').bind( 'click', ToggleMoreDiv );

    $('.ShowDetails').trigger('click');

    BindDelBtn();

    $('#ChecklistTemplate').bind( 'change', NewFromTemplate );

    $('.MoveIcon').bind('click', function() {
        // show modal: ask for ticket number + ok/cancel buttons
        var FormHTML = $('#MoveToTicketDiv').clone().html().replace("name=","id=");

        var Pos    = $(this).attr('id').replace('Move_', '');
        var Item   = $( '#ItemTitle_' + Pos ).val();
        var ItemID = $( '#ItemID_' + Pos ).val();

        while ( Item.length < 70 ) {
            Item += " ";
        }

        Item = Item.replace( /\s/g, '&nbsp;' );

        Core.UI.Dialog.ShowDialog({
            Modal: true,
            Title: Core.Config.Get('PSMoveToTicketTitle') + ": " + Item,
            HTML: FormHTML,
            PositionTop: '100px',
            PositionLeft: 'Center',
            Buttons: [
                {
                    Label: Core.Config.Get('PSTranslationOK'),
                    Function: function() {
                        MoveToTicket( ItemID, $('#TargetTicketNr').val(), Pos );

                        Core.UI.Dialog.CloseDialog($('.Dialog:visible'));
                    }
                },
                {
                    Label: Core.Config.Get('PSTranslationCancel'),
                    Function: function() {
                        Core.UI.Dialog.CloseDialog($('.Dialog:visible'));
                    }
                }
            ]
        });
    });

    function MoveToTicket( ChecklistItemID, TicketNr, Pos ) {
        // AJAX request to move task to ticket
        var URL = Core.Config.Get('Baselink'), Data = {
            Action: 'AgentTicketChecklist',
            Subaction: 'MoveItemToTicket',
            TicketNumber: TicketNr,
            ItemID: ChecklistItemID,
            TicketID: $('#TicketID').val()
        };

        if (!Core.Config.Get('SessionIDCookie')) {
            Data[Core.Config.Get('SessionName')] = Core.Config.Get('SessionID');
            Data[Core.Config.Get('CustomerPanelSessionName')] = Core.Config.Get('SessionID');
        }


        $.ajax({
            type: 'POST',
            url: URL,
            dataType: 'json',
            data : Data,
            success: function ( Response ) {
                if ( Response.Success && Response.Success == 1 ) {
                     $('div[class="Header"]').after(
                         $('<div class="MessageBox" style="background-color: green; color: #ffffff"><p>' + Core.Config.Get('PSMoveToTicketSuccess') + '</p></div>' )
                     );

                     $('#Item_' + Pos).remove();
                }
                else if ( Response.Success == 0 && Response.Message === "NoAccess" ) {
                     $('div[class="Header"]').after(
                         $('<div class="MessageBox Error"><p>' + Core.Config.Get('PSMoveToTicketError') + '</p></div>' )
                     );
                }
            }
        });
    }

    $('#ShowChecklistTextarea').on('click', function() {
        $('#ChecklistTextareaDiv').removeClass("Hidden");
    });

    $('#FromTextarea').on('click', function() {
        var Sort = 1;

        var Lines        = $('#ChecklistTextarea').val().split(/\r?\n/);
        var TmpPositions = parseInt( Positions, 10 );
        var NewPositions = TmpPositions + Lines.length;

        $.each( Lines, function( Index, TodoItem ) {
            NewItem ( TodoItem, TmpPositions + Index + 1, NewPositions, Sort);
        });

        $('#ChecklistTextareaDiv').addClass("Hidden");
    });


    /**
     * Autocomplete stuff
     */

    /**
     * @function
     * @param {jQueryObject} $Input Input element to add auto complete to
     * @param {String} Subaction Subaction to execute, "SearchCustomerID" or "SearchCustomerUser"
     * @return nothing
     */
    TargetNS.AutocompleteInit = function ($Input, Subaction, TargetField) {
        var Keyword = 'Responsible';
        
        if ( TargetField && TargetField != '' ) {
            Keyword = TargetField;
        }

        Core.UI.Autocomplete.Init($Input, function (Request, Response) {
                var URL = Core.Config.Get('Baselink'), Data = {
                    Action: 'AgentTicketChecklistResponsibleSearch',
                    Term: Request.term
                };

                if (!Core.Config.Get('SessionIDCookie')) {
                    Data[Core.Config.Get('SessionName')] = Core.Config.Get('SessionID');
                    Data[Core.Config.Get('CustomerPanelSessionName')] = Core.Config.Get('SessionID');
                }

                $Input.data('AutoCompleteXHR', Core.AJAX.FunctionCall(URL, Data, function (Result) {
                    var Data = [];
                    $Input.removeData('AutoCompleteXHR');
                    $.each(Result, function () {
                        Data.push({
                            label: this.Label,
                            value: this.Value
                        });
                    });
                    Response(Data);
                }));
        }, function (Event, UI) {
            $('#' + Keyword ).val(UI.item.value);
            $Input.val(UI.item.label);
        }, Keyword + 'Search');
    };

    return TargetNS;
}(PS.TicketChecklist || {}));

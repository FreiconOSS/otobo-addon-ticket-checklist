// --
// PS.TicketChecklistWidget.js - provides the special module functions for the time tracking add on
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file COPYING for license information (AGPL). If you
// did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var PS = PS || {};

/**
 * @namespace
 * @exports TargetNS as PS.TicketChecklist
 * @description
 *      This namespace contains the special module functions for the time tracking add on
 */
PS.TicketChecklistWidget = (function (TargetNS) {

    var BaseURL = window.location.href.replace( window.location.search, "" );

    TargetNS.ShowHiddenItems = function( Value ) {
        var ElementID = $('#TicketChecklistWidget').parent().prop('id');
        var Actions   = Core.Config.Get('AsyncWidgetActions') || {};
        var URLPart   = Actions[ElementID] + "&PSTicketChecklistShowHiddenItems=" + Value;
        Core.AJAX.ContentUpdate($('#' + ElementID), Core.Config.Get('Baselink') + URLPart );
    };


    function UpdateItem ( ItemID, ItemStatusID, ItemTicketID, Position ) {

        // show dialog for change note if enabled via sysconfig
        if ( Core.Config.Get('PSChecklistChangeNoteWidget') && Core.Config.Get('PSChecklistChangeNoteWidget') == 1 ) {
            var Epoch                = new Date().getTime();
            var NoteID               = 'ChangeNote-' + Epoch;
            var Cols                 = $('#ChangeNoteDialogCols').val() || 30;
            var Rows                 = $('#ChangeNoteDialogRows').val() || 10;
            var IsMandatory          = Core.Config.Get('PSChecklistMandatoryChangeNote');
            var ChangeNoteDialogHTML = '<textarea id="' + NoteID + '" rows="' + Rows + '" cols="' + Cols + '"></textarea>';

            Core.UI.Dialog.ShowDialog({
                Modal: true,
                Title: $('#ChangeNoteDialogTitle').val(),
                HTML: ChangeNoteDialogHTML,
                PositionTop: '100px',
                PositionLeft: 'Center',
                Buttons: [
                    {
                        Label: $('#ChangeNoteDialogOkButton').val(),
                        Function: function() {
                            if ( IsMandatory && IsMandatory == 1 && $('#' + NoteID).val() == "" ) {
                                $('#ChangeNoteErrorMsg').show();
                                return;
                            }

                            DoUpdateRequest ( ItemID, ItemStatusID, ItemTicketID, Position, $('#' + NoteID).val() );
                            Core.UI.Dialog.CloseDialog($('.Dialog:visible'));
                        }
                    },
                ]
            });
        }
        else {
            DoUpdateRequest ( ItemID, ItemStatusID, ItemTicketID, Position );
        }
    }

    function DoUpdateRequest ( ItemID, ItemStatusID, ItemTicketID, Position, ChangeNoteText ) {
        var URL = Core.Config.Get('Baselink') || BaseURL;

        $.ajax({
            type: 'POST',
            url: URL,
            dataType: 'json',
            data : {
                Action: 'AgentTicketChangeChecklistStatus',
                ID: ItemID,
                Status: ItemStatusID,
                TicketID: ItemTicketID,
                ItemPosition: Position,
                ChangeNote: ChangeNoteText
            },
            success: function(response) {
                if ( response.Error ) {
                    return;
                }

                $('#ItemFlag_' + response.Position).css( 'background-color', response.Color );

                if ( response.ChangeNote ) {
                    $('#ChangeNote_' + response.Position).html( response.ChangeNote );
                }

                if ( Core.Config.Get('TicketChecklist.ReloadTicketZoom') ) {
                    window.location.reload(true);
                    return;
                }

                if ( Core.Config.Get('TicketChecklist.ReloadChecklist') ) {
                    TargetNS.ReloadChecklistWidget(ItemTicketID);
                }
            }
        });
    };

    TargetNS.Init = function() {
        Core.UI.InputFields.InitSelect( $('select[id^="ItemStatusWidget_"]') );

        $('#PS-Checklist-Customer-View').bind('change', function() {
            var is_checked = 0;

            if ($(this).is(':checked') ) {
                is_checked = 1;
            }

            var URL = Core.Config.Get('Baselink') || BaseURL;
            $.ajax({
                type: 'POST',
                url: URL,
                dataType: 'json',
                data : {
                    Action: 'AgentTicketChecklistCustomerVisibility',
                    TicketID: Core.Config.Get("TicketID"),
                    CustomerVisibility: is_checked
                }
            });
        });

        if ( Core.Config.Get('PS.Checklist.DetailsOnMouseover') == 1 ) {
            $('.ChecklistTask').bind('mouseover', function(Event) {
                var XDiff = 120;
                var YDiff = 180;

                if ( Core.Config.Get('PS.Checklist.Prefix') == "Complex" ) {
                    XDiff = 140;
                    YDiff = 270;
                }
               
                var MouseLeft = parseInt( Event.clientX, 10 ) - XDiff;
                var MouseTop  = parseInt( Event.clientY, 10 ) - YDiff;

                var ElemID    = $(this).attr('id').replace("Task-", "").replace("ItemComplexInfoLink-","");

                $('div#ComplexChecklistItemDetails').html( $('#ItemInfo-' + ElemID).clone().html() );

                $('div#ComplexChecklistItemDetails')
                    .css( 'left',    MouseLeft )
                    .css( 'top',     MouseTop )
                    .css( 'z-index', 1000 )
		    .removeClass('Hidden')
                    .show();
            });

            $('.ChecklistTask').bind('mouseout', function() {
                $('div#ComplexChecklistItemDetails').hide();
            });
        }
        else {
            $('a.ItemInfo').bind('click', function (Event) {
                $('div.ChecklistItemDetails').each( function() { $(this).hide() } );

                var MouseLeft = parseInt( Event.pageX, 10 ) - 420;
                var MouseTop  = parseInt( Event.pageY, 10 ) - 150;

                var ElemID    = $(this).attr('id').replace("Link", "");

                $('#' + ElemID)
                    .css( 'left',  MouseLeft )
                    .css( 'top',   MouseTop ) 
                    .show();

                return false;
            });

            $('a.ItemComplexInfo').bind('click', function (Event) {
                var MouseLeft = parseInt( Event.pageX, 10 ) - 150;
                var MouseTop  = parseInt( Event.pageY, 10 ) - 320;

                var ElemID = $(this).attr('id').replace("Link", "");
                ElemID     = ElemID.replace("Complex", "");

                $('div#ComplexChecklistItemDetails').html( $('#' + ElemID).clone().html() );

                $('a.ItemInfoClose').bind( 'click', function() {
                    $(this).closest( '#ComplexChecklistItemDetails' ).hide();
                    return false;
                });

                $('div#ComplexChecklistItemDetails')
                    .css( 'left',  MouseLeft )
                    .css( 'top',   MouseTop )
                    .show();

                return false;
            });

            $('a.ItemInfoClose').bind( 'click', function() {
                $(this).closest( '.ChecklistItemDetails' ).hide();
                $(this).closest( '#ComplexChecklistItemDetails' ).hide();
                return false;
            });
        }

        $('select[name^="ItemStatusWidget"]').bind( 'change', function() {
            var Pos       = $(this).attr('id').match( /\d+/ );
            var ID        = $('#ItemID_' + Pos[0]);
            var TicketID  = $('#ChecklistTicketID').val();

            if ( ID ) {
                UpdateItem( ID.val(), $(this).val(), TicketID, Pos[0] );
            }

            return false;
        });

        $('#my_todos').bind( 'change', function() {
            var Filter = '';
            if ( $(this).is(':checked') ) {
                Filter = 'MyTodos';
            }

            $('.ExportLink').each( function() {
                var Href = $(this).attr('href').replace(/Filter=.*/, "Filter=" + Filter);
                $(this).attr('href', Href);
            });
        });
    }

    //TargetNS.Init();

    TargetNS.GotoArticle = function( ArticleID ) {
        if ( $('.AllArticles').hasClass('Active') ) {
            window.location.hash = 'Article' + ArticleID;
        }

        window.location.hash = ArticleID;
        Core.Agent.TicketZoom.CheckURLHash();
    };


    TargetNS.ReloadChecklist = function() {
        var URL          = Core.Config.Get('Baselink');
        var TicketFormID = $('input[name="FormID"]').val();

        var FormData = {
            Action: 'AgentTicketChecklistIDSet',
            Subaction: 'ReloadWidget',
            FormID: TicketFormID
        };

        if (!Core.Config.Get('SessionIDCookie')) {
            FormData[Core.Config.Get('SessionName')] = Core.Config.Get('SessionID');
            FormData[Core.Config.Get('CustomerPanelSessionName')] = Core.Config.Get('SessionID');
        }

        jQuery.ajax({
            url: URL,
            data: FormData,
            dataType: 'json',
            success: function (Response){
                if ( !Response ) {
                    Core.Exception.Throw('Invalid JSON from ' + URL, 'CommunicationError');
                }
                else if ( Response.HasHTML ) {
                    var Widget = $('#TicketChecklistWidget').parent();
                    $('#TicketChecklistWidget').remove();
                    Widget.append( Response.HTML );

                    $('#EditChecklistBtn').unbind('click');
                    $('#EditChecklistBtn').bind('click', function (Event) {
                        var PopupType = 'TicketAction';
                        Core.UI.Popup.OpenPopup($(this).attr('href'), PopupType);
                        return false;
                    });

                    $('a.ItemInfo').unbind('click');
                    $('a.ItemInfoClose').unbind('click');

                    Core.UI.InputFields.InitSelect( $('select[id^="ItemStatusWidget_"]') );
                    Core.UI.InputFields.InitSelect( $('select[id^="ItemStatus_"]') );

                    Core.UI.InitWidgetActionToggle();
                }
            }
        });
    }

    TargetNS.ReloadChecklistWidget = function(ItemTicketID) {
        var URL = Core.Config.Get('Baselink');

        var FormData = {
            Action: 'AgentTicketChecklist',
            Subaction: 'ReloadWidget',
            TicketID: ItemTicketID
        };

        if (!Core.Config.Get('SessionIDCookie')) {
            FormData[Core.Config.Get('SessionName')] = Core.Config.Get('SessionID');
            FormData[Core.Config.Get('CustomerPanelSessionName')] = Core.Config.Get('SessionID');
        }

        jQuery.ajax({
            url: URL,
            data: FormData,
            dataType: 'json',
            success: function (Response){
                if ( !Response ) {
                    Core.Exception.Throw('Invalid JSON from ' + URL, 'CommunicationError');
                }
                else if ( Response.HasHTML ) {
                    $('#TicketChecklistWidget').replaceWith( Response.HTML );

                    $('a.ItemInfo').unbind('click');
                    $('a.ItemInfoClose').unbind('click');

                    TargetNS.Init();

                    Core.UI.InputFields.InitSelect( $('select[id^="ItemStatusWidget_"]') );
                    Core.UI.InputFields.InitSelect( $('select[id^="ItemStatus_"]') );

                    Core.UI.InitWidgetActionToggle();
                }
            }
        });
    }

    return TargetNS;
}(PS.TicketChecklistWidget || {}));

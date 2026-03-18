import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../widget/componets/restaurant/componets/Button.dart';
import '../../../../widget/componets/restaurant/componets/filterButton.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/presentation/widget/componets/common/app_text_field.dart';

class DeliveryDetails extends StatefulWidget {
  const DeliveryDetails({super.key});

  @override
  State<DeliveryDetails> createState() => _DeliveryDetailsState();
}
enum PaymentMode {paynow ,paylater }

class _DeliveryDetailsState extends State<DeliveryDetails> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController numberController = TextEditingController();
  final TextEditingController remarkController = TextEditingController();
  final TextEditingController houseController = TextEditingController();
  final TextEditingController stateController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController areaController = TextEditingController();
  final TextEditingController postCodeController = TextEditingController();
  final TextEditingController deliveryController = TextEditingController();

  PaymentMode? _character = PaymentMode.paynow;
  String selectedFilter = "Cash";
  Widget _getBody() {
    switch (selectedFilter) {
      case "Cash":
        return Text('');
      case "Card":
        return  Text('');
      default:
        return Center(
          child: Text('NO DATA AVAILABE'),
        );
    }
  }
  bool ispaynow = false;
  @override
  Widget build(BuildContext context) {
    final heigth = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title:Text('Due',style: GoogleFonts.poppins(fontWeight: FontWeight.w600,fontSize: 16),),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, ),
          onPressed: () => Navigator.pop(context),
        ),


      ),
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10,vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer Details ',style: GoogleFonts.poppins(fontWeight: FontWeight.w500),),
              SizedBox(height: 10,),
              AppTextField(
                controller: nameController,
                label: 'Name',
                icon: Icons.person_outline,
              ),
              SizedBox(height: 10,),

              AppTextField(
                controller: emailController,
                label: 'Email ID (optional)',
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 10,),

              AppTextField(
                controller: numberController,
                label: 'Mobile No',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 25,),

              AppTextField(
                controller: remarkController,
                label: 'Remarks',
                icon: Icons.note_alt_outlined,
              ),
              Divider(),

              Text('Address',style: GoogleFonts.poppins(fontSize: 16,fontWeight: FontWeight.w600),),
              Divider(),
              AppTextField(
                controller: houseController,
                label: 'House NO',
                icon: Icons.home_outlined,
              ),
              SizedBox(height: 10,),
              AppTextField(
                controller: stateController,
                label: 'State',
                icon: Icons.location_on_outlined,
              ),
              SizedBox(height: 10,),
              AppTextField(
                label: 'City',
                icon: Icons.location_city_outlined,
              ),
              SizedBox(height: 10,),
              AppTextField(
                label: 'Area',
                icon: Icons.map_outlined,
              ),
              SizedBox(height: 10,),
              AppTextField(
                label: 'Post Code',
                icon: Icons.local_post_office_outlined,
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 10,),
              Divider(),

              // delivery charge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: width * 0.6,
                    child: AppTextField(
                      controller: deliveryController,
                      label: 'Delivery Charge',
                      icon: Icons.delivery_dining_outlined,
                      keyboardType: TextInputType.number,
                    ),
                  ),

                  CommonButton(
                      bgcolor: Colors.grey.shade300,
                      bordercircular: 5,
                      bordercolor: Colors.grey.shade300,
                      height: heigth * 0.05,
                      width: width *0.3,
                      onTap: (){},
                      child: Text('Apply'))

                ],
              ),

              Divider(),


              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(5),
                      decoration: BoxDecoration(
                          border: Border.all(width: 1, color: Colors.grey)
                      ),
                      child: ListTile(
                        title: Text('Pay Now',style: GoogleFonts.poppins(fontWeight: FontWeight.w600, ),),
                        leading: Radio<PaymentMode>(
                            value: PaymentMode.paynow,
                            groupValue: _character,
                            activeColor: Colors.black,

                            onChanged:(PaymentMode? value){
                              setState(() {
                                _character = value;
                                // ispaynow = true;
                              });
                            }),
                      ),
                    ),
                  ),
                  SizedBox(width: 5,),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(5),
                      decoration: BoxDecoration(
                          border: Border.all(width: 1, color: Colors.grey)
                      ),
                      child: ListTile(
                        title: Text('Pay Later'),
                        leading: Radio<PaymentMode>(
                            activeColor: Colors.black,
                            value: PaymentMode.paylater,
                            groupValue: _character,
                            onChanged:(PaymentMode? value){
                              setState(() {
                                _character = value;
                                // ispaynow = false;
                              });
                            }),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(
                height: 10,
              ),
              _character == PaymentMode.paynow?
              ExpansionTile(
                childrenPadding: EdgeInsets.all(10),
                title:  Text('Payment Type'),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Filterbutton(
                          borderc: 5,
                          title: 'Cash',
                          selectedFilter: selectedFilter,
                          onpressed:() {
                            setState(() {
                              selectedFilter = 'Cash';
                            });
                          }),
                      SizedBox(width: 10,),
                      Filterbutton(
                          borderc: 5,
                          title: 'Card',
                          selectedFilter: selectedFilter,
                          onpressed:() {
                            setState(() {
                              selectedFilter = 'Card';
                            });
                          }),
                    ],)
                ],

              ) :
              SizedBox(),
              SizedBox(
                height: 10,
              ),
              CommonButton(
                  bordercircular: 5,
                  height: heigth * 0.05,
                  onTap: (){},
                  child: Text('Procced',style: GoogleFonts.poppins(fontWeight: FontWeight.w600,color: Colors.white),))


            ],),
        ),
      ),
    );
  }
}
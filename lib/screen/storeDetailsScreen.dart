import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:unipos/stores/setup_wizard_store.dart';
import '../util/color.dart';

/// Store Details Step
/// UI Only - uses Observer to listen to store changes
/// Calls store methods for actions
class StoreDetailsStep extends StatefulWidget {
  final SetupWizardStore store;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const StoreDetailsStep({
    Key? key,
    required this.store,
    required this.onNext,
    required this.onPrevious,
  }) : super(key: key);

  @override
  State<StoreDetailsStep> createState() => _StoreDetailsStepState();
}

class _StoreDetailsStepState extends State<StoreDetailsStep> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for text fields
  late TextEditingController _storeNameController;
  late TextEditingController _ownerNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _gstController;
  late TextEditingController _panController;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with store values
    // Initialize controllers with store values
    _storeNameController = TextEditingController(text: widget.store.storeName);
    _ownerNameController = TextEditingController(text: widget.store.ownerName);
    _phoneController = TextEditingController(text: widget.store.phone);
    _emailController = TextEditingController(text: widget.store.email);
    _addressController = TextEditingController(text: widget.store.address);
    _gstController = TextEditingController(text: widget.store.gstin);
    _panController = TextEditingController(text: widget.store.pan);
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _gstController.dispose();
    _panController.dispose();
    super.dispose();
  }

  void _syncToStore() {
    widget.store.setStoreName(_storeNameController.text);
    widget.store.setOwnerName(_ownerNameController.text);
    widget.store.setPhone(_phoneController.text);
    widget.store.setEmail(_emailController.text);
    widget.store.setAddress(_addressController.text);
    widget.store.setGstin(_gstController.text);
    widget.store.setPan(_panController.text);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Store Information',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.darkNeutral,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Basic details about your store',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 30),

            // Store Name
            TextFormField(
              controller: _storeNameController,
              decoration: InputDecoration(
                labelText: 'Store Name*',
                prefixIcon: Icon(Icons.store, color: AppColors.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) => widget.store.setStoreName(value),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Store name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Owner Name
            TextFormField(
              controller: _ownerNameController,
              decoration: InputDecoration(
                labelText: 'Owner Name*',
                prefixIcon: Icon(Icons.person, color: AppColors.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) => widget.store.setOwnerName(value),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Owner name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            /*------------------Image Upload-------------*/

            Card(
              elevation: 5,
              color: Colors.white,
              child: Observer(
                  builder:(_){
                    bool hasImage = widget.store.logoByte != null;
                    return InkWell(
                      onTap: (){
                        widget.store.pickLogo();
                      },
                      child: Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          color: hasImage ? Colors.black : Colors.teal.shade100,
                          image: hasImage?
                              DecorationImage(
                                image: MemoryImage(widget.store.logoByte!),
                                fit: BoxFit.contain
                              )
                              :null
                        ),
                        child: Stack(
                          children: [
                            if(!hasImage)
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children:[
                                    Icon(Icons.image,color: Colors.teal.shade700,size: 60,),
                                    SizedBox(height: 10,),

                                    Text('UPLOAD LOGO',style: TextStyle(fontSize:16,color: Colors.teal.shade900,
                                    fontWeight:FontWeight.w600
                                    ),)

                                  ]
                                ),
                              ),


                            if(hasImage)
                              Positioned(

                                  child: InkWell(
                                onTap: (){
                                  widget.store.deleteLogo();
                                },
                                    child: Container(
                                      padding: EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                        border: Border.all(color:Colors.white,width: 2),
                                      ),
                                      child: Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),

                              ))

                          ],
                        ),
                      ),
                    );
                  } ),
            ),


   /*         Card(
              elevation: 5,
              child: InkWell(
                onTap: (){
                 widget.store.pickLogo();
                },
                child: Container(
                  width: double.infinity,
                  height: 200,
                  // color: Colors.teal.shade100,
                    child: Observer(
                      builder: (_){
                        if(widget.store.logoByte != null){
                          return Container(

                              child: Stack(
                               children: [

                                 Icon(Icons.delete,color: Colors.red,size: 100,),

                                 Image.memory(widget.store.logoByte!)

                               ],

                              ));
                        }else{
                          return  Icon(Icons.image,color: Colors.white,size: 100,);
                        }
                      },
                    ),





                    *//*child:Column(
                      mainAxisAlignment:MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image,color: Colors.white,size: 100,),
                      Text('UPLOAD LOGO',style: TextStyle(fontSize:20,color: Colors.white,fontWeight: FontWeight.w600),),
                    ],
                  )*//*
                ),
              ),
            ),*/

            const SizedBox(height: 20,),


            // Phone & Email Row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number*',
                      prefixIcon: Icon(Icons.phone, color: AppColors.primary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) => widget.store.setPhone(value),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Phone is required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email, color: AppColors.primary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) => widget.store.setEmail(value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Address
            TextFormField(
              controller: _addressController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Store Address',
                prefixIcon: Icon(Icons.location_on, color: AppColors.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) => widget.store.setAddress(value),
            ),
            const SizedBox(height: 20),

            // GST & PAN Row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _gstController,
                    decoration: InputDecoration(
                      labelText: 'GST Number (Optional)',
                      prefixIcon: Icon(Icons.receipt_long, color: AppColors.primary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) => widget.store.setGstin(value),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _panController,
                    decoration: InputDecoration(
                      labelText: 'PAN Number (Optional)',
                      prefixIcon: Icon(Icons.credit_card, color: AppColors.secondary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8F9FA),
                    ),
                    onChanged: (value) => widget.store.setPan(value),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // Navigation Buttons
            Observer(
              builder: (_) => Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _syncToStore();
                        widget.onPrevious();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _syncToStore();
                          widget.store.saveBusinessDetails();
                          widget.onNext();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: widget.store.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Continue',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}